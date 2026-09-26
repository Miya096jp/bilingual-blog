require "test_helper"

class CsrfProtectionTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  # OAuthの資格情報がない環境ではDeviseがomniauth用のURLヘルパーを定義せず、
  # ログインフォームのソーシャルボタンが描画できないため、ダミーを定義する
  if Devise.omniauth_configs.empty?
    Users::SessionsController.helper(Module.new { def omniauth_authorize_path(*) = "#" })
  end

  setup do
    @original_allow_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    @user = users(:one)
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @original_allow_forgery_protection
  end

  test "CSRFトークンなしでログインをPOSTすると拒否され、トップへ戻される" do
    post user_session_path, params: { user: { email: @user.email, password: "password123" } }

    assert_redirected_to root_path(locale: "ja")
    assert_equal "ページの有効期限が切れました。もう一度お試しください。", flash[:alert]
    assert_nil session["warden.user.user.key"]
  end

  test "正しいCSRFトークン付きでログインをPOSTすると成功する" do
    post user_session_path, params: {
      authenticity_token: fetch_authenticity_token,
      user: { email: @user.email, password: "password123" }
    }

    assert_response :see_other
    assert_not_nil session["warden.user.user.key"]
  end

  test "CSRFトークンなしでアカウント削除を送ると拒否される" do
    sign_in @user

    assert_no_difference("User.count") do
      delete user_registration_path
    end

    assert_redirected_to root_path(locale: "ja")
    assert User.exists?(@user.id)
  end

  private

  def fetch_authenticity_token
    get new_user_session_path, headers: { "Turbo-Frame" => "auth_form_frame" }
    assert_response :success

    response.body[/name="authenticity_token" value="([^"]+)"/, 1].tap do |token|
      assert token.present?, "ログインフォームにauthenticity_tokenが見つからない"
    end
  end
end
