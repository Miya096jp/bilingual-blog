namespace :images do
  desc "本文から参照されていない画像(PurgeUnreferencedImagesJob の削除候補)を削除せずに一覧表示する"
  task list_unreferenced: :environment do
    finder = UnreferencedImageFinder.new
    url_options = Rails.application.config.action_mailer.default_url_options || {}

    if finder.unresolvable_urls.any?
      puts "警告: blob に復元できない URL が本文にあるため、定期ジョブは削除を行わない"
      finder.unresolvable_urls.each { |url| puts "  #{url}" }
    end

    candidates = finder.candidates.order(:created_at)
    puts "削除候補: #{candidates.count} 件"
    candidates.find_each do |blob|
      # 本文に埋め込まれるのと同じ形式の URL。variant の生成のみで変換処理は行わない
      variant = blob.variant(UnreferencedImageFinder::BODY_IMAGE_VARIANT)
      url = Rails.application.routes.url_helpers.polymorphic_url(variant, **url_options)
      puts [ blob.id, blob.filename, blob.byte_size, blob.created_at.iso8601, url ].join("\t")
    end
  end
end
