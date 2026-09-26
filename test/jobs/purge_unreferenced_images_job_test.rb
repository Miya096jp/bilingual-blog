require "test_helper"

class PurgeUnreferencedImagesJobTest < ActiveJob::TestCase
  test "公開記事・下書き記事の本文で使われている画像は削除されない" do
    published_image = create_blob(created_at: 8.days.ago)
    draft_image = create_blob(created_at: 8.days.ago)
    articles(:published_ja).update!(content: "本文\n\n#{image_markdown(published_image)}")
    articles(:draft_ja).update!(content: image_markdown(draft_image))

    PurgeUnreferencedImagesJob.perform_now

    assert ActiveStorage::Blob.exists?(published_image.id)
    assert ActiveStorage::Blob.exists?(draft_image.id)
  end

  test "プロフィール本文(日英)で使われている画像は削除されない" do
    ja_image = create_blob(created_at: 8.days.ago)
    en_image = create_blob(created_at: 8.days.ago)
    users(:one).update_columns(profile_body_ja: image_markdown(ja_image), profile_body_en: image_markdown(en_image))

    PurgeUnreferencedImagesJob.perform_now

    assert ActiveStorage::Blob.exists?(ja_image.id)
    assert ActiveStorage::Blob.exists?(en_image.id)
  end

  test "どこからも使われていない画像は削除される" do
    unused_image = create_blob(created_at: 8.days.ago)

    PurgeUnreferencedImagesJob.perform_now

    assert_not ActiveStorage::Blob.exists?(unused_image.id)
  end

  test "作成から7日以内の画像は削除されない" do
    recent_image = create_blob(created_at: 6.days.ago)

    PurgeUnreferencedImagesJob.perform_now

    assert ActiveStorage::Blob.exists?(recent_image.id)
  end

  test "日英2本の記事で同じ画像を使っていて片方だけを削除しても画像は残る" do
    shared_image = create_blob(created_at: 8.days.ago)
    articles(:published_ja).update!(content: image_markdown(shared_image))
    articles(:published_en).update!(content: image_markdown(shared_image))

    articles(:published_en).destroy!
    PurgeUnreferencedImagesJob.perform_now

    assert ActiveStorage::Blob.exists?(shared_image.id)
  end

  test "blob に復元できない Active Storage の URL が本文にあるときは何も削除しない" do
    unused_image = create_blob(created_at: 8.days.ago)
    articles(:draft_ja).update!(content: "![broken](https://dualpascal.com/rails/active_storage/representations/redirect/invalid--signature/key/broken.png)")

    PurgeUnreferencedImagesJob.perform_now

    assert ActiveStorage::Blob.exists?(unused_image.id)
  end

  test "既に削除済みの画像への参照が本文にあっても、使われていない画像は削除される" do
    deleted_image = create_blob(created_at: 8.days.ago)
    articles(:draft_ja).update!(content: image_markdown(deleted_image))
    deleted_image.purge
    unused_image = create_blob(created_at: 8.days.ago)

    PurgeUnreferencedImagesJob.perform_now

    assert_not ActiveStorage::Blob.exists?(unused_image.id)
  end

  private

  def create_blob(created_at:)
    blob = ActiveStorage::Blob.create_and_upload!(
      io: file_fixture("portrait.png").open,
      filename: "portrait.png",
      content_type: "image/png"
    )
    blob.update_columns(created_at: created_at)
    blob
  end

  # Dashboard::ImagesController#create が本文に埋め込ませる URL と同じ形式
  def image_markdown(blob)
    variant = blob.variant(UnreferencedImageFinder::BODY_IMAGE_VARIANT)
    url = Rails.application.routes.url_helpers.polymorphic_url(variant, host: "dualpascal.com", protocol: "https")
    "![#{blob.filename}](#{url})"
  end
end
