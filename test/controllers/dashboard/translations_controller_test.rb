require "test_helper"

class Dashboard::TranslationsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:blogger)
    @original = articles(:published_ja)
    @translation = articles(:published_en)
    sign_in @user
  end

  test "カバー画像をファイルでアップロードできる" do
    file = fixture_file_upload("portrait.png", "image/png")
    patch dashboard_article_translation_path(@original), params: { article: { cover_image: file } }

    assert_redirected_to dashboard_articles_path
    assert @translation.reload.cover_image.attached?
  end

  test "カバー画像にsigned_idの文字列を送っても添付されない" do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: File.open(file_fixture("portrait.png")),
      filename: "portrait.png",
      content_type: "image/png"
    )

    patch dashboard_article_translation_path(@original), params: { article: { cover_image: blob.signed_id } }

    assert_not @translation.reload.cover_image.attached?
  end
end
