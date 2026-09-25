require "test_helper"

class Dashboard::AttachmentsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @owner = users(:blogger)
    @article = articles(:published_ja)
    @article.cover_image.attach(io: File.open(file_fixture("portrait.png")), filename: "cover.png", content_type: "image/png")
    @owner.avatar.attach(io: File.open(file_fixture("portrait.png")), filename: "avatar.png", content_type: "image/png")
  end

  test "自分の記事のカバー画像は削除できる" do
    sign_in @owner
    attachment = @article.cover_image.attachment

    delete dashboard_attachment_path(attachment)

    assert_response :redirect
    assert_not @article.reload.cover_image.attached?
  end

  test "自分のアバターは削除できる" do
    sign_in @owner
    attachment = @owner.avatar.attachment

    delete dashboard_attachment_path(attachment)

    assert_response :redirect
    assert_not @owner.reload.avatar.attached?
  end

  test "他ユーザーの記事のカバー画像を削除しようとすると404になり削除されない" do
    sign_in users(:one)
    attachment = @article.cover_image.attachment

    delete dashboard_attachment_path(attachment)

    assert_response :not_found
    assert @article.reload.cover_image.attached?
  end

  test "他ユーザーのアバターを削除しようとすると404になり削除されない" do
    sign_in users(:one)
    attachment = @owner.avatar.attachment

    delete dashboard_attachment_path(attachment)

    assert_response :not_found
    assert @owner.reload.avatar.attached?
  end
end
