require "test_helper"

class ActiveStorageDirectUploadTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def direct_upload_params
    content = "0123456789"
    {
      blob: {
        filename: "payload.exe",
        byte_size: content.bytesize,
        checksum: OpenSSL::Digest::MD5.base64digest(content),
        content_type: "application/octet-stream"
      }
    }
  end

  test "未ログインでdirect uploadを送ると404になり、blobが作成されない" do
    assert_no_difference("ActiveStorage::Blob.count") do
      post rails_direct_uploads_path, params: direct_upload_params, as: :json
    end

    assert_response :not_found
  end

  test "ログイン済みでもdirect uploadは404になり、blobが作成されない" do
    sign_in users(:blogger)

    assert_no_difference("ActiveStorage::Blob.count") do
      post rails_direct_uploads_path, params: direct_upload_params, as: :json
    end

    assert_response :not_found
  end

  test "既存の画像の表示URL(representationsのredirect)は従来どおり応答する" do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: File.open(file_fixture("portrait.png")),
      filename: "portrait.png",
      content_type: "image/png"
    )

    get url_for(blob.variant(resize_to_limit: [ 800, 600 ]))

    assert_response :redirect
  end
end
