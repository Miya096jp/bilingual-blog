require "test_helper"

class AccountSuspensionTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  # OAuthの資格情報がない環境ではDeviseがomniauth用のURLヘルパーを定義せず、
  # レイアウトのログインモーダルが描画できないため、このテストに限りダミーを定義する
  if Devise.omniauth_configs.empty?
    [ ArticlesController, SearchController ].each do |controller|
      controller.helper(Module.new { def omniauth_authorize_path(*) = "#" })
    end
  end

  test "停止中のユーザーはパスワードでログインできず、停止中である旨のメッセージが表示される" do
    user = users(:suspended)

    post user_session_path, params: { user: { email: user.email, password: "password123" } }

    assert_redirected_to new_user_session_path
    follow_redirect!
    assert_redirected_to root_path(locale: "ja")
    assert_equal I18n.t("devise.failure.suspended", locale: :ja), flash[:alert]

    get dashboard_articles_path
    assert_redirected_to new_user_session_path
  end

  test "停止中のユーザーはOmniAuthでログインできない" do
    user = users(:suspended)

    get user_github_omniauth_callback_path, env: { "omniauth.auth" => omniauth_hash(user.email) }

    assert_redirected_to new_user_session_path
    follow_redirect!
    assert_equal I18n.t("devise.failure.suspended", locale: :ja), flash[:alert]

    get dashboard_articles_path
    assert_redirected_to new_user_session_path
  end

  test "停止していないユーザーはOmniAuthでログインできる" do
    user = users(:blogger)

    get user_github_omniauth_callback_path, env: { "omniauth.auth" => omniauth_hash(user.email) }

    get dashboard_articles_path
    assert_response :success
  end

  test "ログイン中のユーザーを停止すると、次のリクエストでログアウトされる" do
    user = users(:blogger)
    sign_in user

    get dashboard_articles_path
    assert_response :success

    user.suspend!

    get dashboard_articles_path
    assert_redirected_to new_user_session_path
    follow_redirect!
    assert_redirected_to root_path(locale: "ja")
    assert_equal I18n.t("devise.failure.suspended", locale: :ja), flash[:alert]

    user.restore!
    get dashboard_articles_path
    assert_redirected_to new_user_session_path
  end

  test "停止を解除すると、パスワードでログインでき、ブログも表示される" do
    user = users(:suspended)
    user.restore!

    post user_session_path, params: { user: { email: user.email, password: "password123" } }
    get dashboard_articles_path
    assert_response :success

    get user_articles_path(user.username, locale: "ja")
    assert_response :success
  end

  private

  def omniauth_hash(email)
    OmniAuth::AuthHash.new(
      provider: "github",
      uid: "12345",
      info: { email: email, nickname: "someone" }
    )
  end
end
