require "test_helper"

class Dashboard::ImagesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:blogger)
  end

  test "許可された形式・サイズの画像はアップロードでき、URLが返る" do
    sign_in @user
    file = fixture_file_upload("portrait.png", "image/png")
    before_count = ActiveStorage::Blob.count

    post dashboard_images_path, params: { image: file }

    assert_response :success
    assert_operator ActiveStorage::Blob.count, :>, before_count
    assert_not_nil JSON.parse(response.body)["url"]
  end

  test "許可されていない形式のファイルは422になり、blobが作成されない" do
    sign_in @user
    file = Rack::Test::UploadedFile.new(
      StringIO.new("PK\x03\x04fake zip content"),
      "application/zip",
      true,
      original_filename: "document.zip"
    )

    assert_no_difference("ActiveStorage::Blob.count") do
      post dashboard_images_path, params: { image: file }
    end

    assert_response :unprocessable_entity
    assert_not_nil JSON.parse(response.body)["error"]
  end

  test "サイズ上限を超える画像は422になり、blobが作成されない" do
    sign_in @user
    oversized_content = File.binread(file_fixture("portrait.png")) + ("0" * 6.megabytes)
    file = Rack::Test::UploadedFile.new(
      StringIO.new(oversized_content),
      "image/png",
      true,
      original_filename: "large.png"
    )

    assert_no_difference("ActiveStorage::Blob.count") do
      post dashboard_images_path, params: { image: file }
    end

    assert_response :unprocessable_entity
    assert_not_nil JSON.parse(response.body)["error"]
  end

  test "拡張子とContent-Typeをimage/pngに偽装したテキストファイルは422になり、blobが作成されない" do
    sign_in @user
    file = Rack::Test::UploadedFile.new(
      StringIO.new("これは画像ではないテキストファイルです"),
      "image/png",
      true,
      original_filename: "fake.png"
    )

    assert_no_difference("ActiveStorage::Blob.count") do
      post dashboard_images_path, params: { image: file }
    end

    assert_response :unprocessable_entity
    assert_not_nil JSON.parse(response.body)["error"]
  end

  test "画像を指定しないリクエストは500ではなく422になる" do
    sign_in @user

    assert_no_difference("ActiveStorage::Blob.count") do
      post dashboard_images_path
    end

    assert_response :unprocessable_entity
    assert_not_nil JSON.parse(response.body)["error"]
  end

  test "未ログインでのリクエストはログイン画面へリダイレクトされる" do
    file = fixture_file_upload("portrait.png", "image/png")

    assert_no_difference("ActiveStorage::Blob.count") do
      post dashboard_images_path, params: { image: file }
    end

    assert_redirected_to new_user_session_path
  end
end
