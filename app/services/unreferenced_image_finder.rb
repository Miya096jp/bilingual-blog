# 本文に貼り付けた画像(Dashboard::ImagesController#create)はどのレコードにも紐づかないため、
# 本文を検索して、どこからも参照されていない画像を削除候補として返す。
# 本文を保存するカラムを追加したら、body_texts に加えること。
class UnreferencedImageFinder
  # Dashboard::ImagesController#create が本文用に生成するバリアントと揃えている
  BODY_IMAGE_VARIANT = { resize_to_limit: [ 800, 600 ] }.freeze
  RETENTION_PERIOD = 7.days
  # Active Storage の blob / representation の全ルート形式から signed_id を取り出す
  ACTIVE_STORAGE_URL_PATTERN = %r{/rails/active_storage/(?:blobs|representations)(?:/redirect|/proxy)?/([^/\s)"']+)/}

  def candidates
    referenced_ids = referenced_blob_ids
    ActiveStorage::Blob.unattached
      .where(created_at: ..RETENTION_PERIOD.ago)
      .where.not(id: referenced_ids)
  end

  # blob に復元できない Active Storage の URL。1つでもあれば判定不能として削除しない
  def unresolvable_urls
    resolve_references
    @unresolvable_urls
  end

  private

  def referenced_blob_ids
    resolve_references
    @referenced_blob_ids
  end

  def resolve_references
    return if @referenced_blob_ids

    @referenced_blob_ids = Set.new
    @unresolvable_urls = []
    body_texts.each do |text|
      text.scan(ACTIVE_STORAGE_URL_PATTERN) do |(signed_id)|
        url = Regexp.last_match[0]
        begin
          @referenced_blob_ids << ActiveStorage::Blob.find_signed!(CGI.unescape(signed_id)).id
        rescue ActiveSupport::MessageVerifier::InvalidSignature
          @unresolvable_urls << url
        rescue ActiveRecord::RecordNotFound
          # 既に削除済みの画像への参照。削除候補にもならないため無視してよい
        end
      end
    end
  end

  # 記事は公開状態・言語を問わず全件を対象にする
  def body_texts
    Article.pluck(:content) + User.pluck(:profile_body_ja, :profile_body_en).flatten.compact
  end
end
