require "test_helper"

class OmniauthLoginTest < ActionDispatch::IntegrationTest
  # OAuthの資格情報がない環境ではDeviseがomniauth用のURLヘルパーを定義せず、
  # レイアウトのログインモーダルが描画できないため、このテストに限りダミーを定義する
  if Devise.omniauth_configs.empty?
    [ ArticlesController, SearchController, Users::SessionsController ].each do |controller|
      controller.helper(Module.new { def omniauth_authorize_path(*) = "#" })
    end
  end

  test "未確認の既存ユーザーと同じメールアドレスでOmniAuthログインすると、確認済みになり、登録時のパスワードは無効になる" do
    user = users(:unconfirmed)
    user.update_columns(confirmation_token: "unconfirmed-token", confirmation_sent_at: Time.current)

    get user_github_omniauth_callback_path, env: { "omniauth.auth" => omniauth_hash(user.email) }
    assert_equal "既存アカウントでログインしました。登録時のパスワードは無効になったため、パスワードでログインする場合は再設定してください", flash[:notice]

    get dashboard_articles_path
    assert_response :success

    user.reload
    assert user.confirmed?
    assert_not user.valid_password?("password123")
    assert_nil user.confirmation_token
    assert_not_empty User.confirm_by_token("unconfirmed-token").errors

    delete destroy_user_session_path
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
    get dashboard_articles_path
    assert_redirected_to new_user_session_path
  end

  test "確認済みの既存ユーザーは、OmniAuthでログインでき、パスワードも変わらない" do
    user = users(:blogger)

    assert_no_changes -> { user.reload.encrypted_password } do
      get user_github_omniauth_callback_path, env: { "omniauth.auth" => omniauth_hash(user.email) }
    end
    assert_equal "既存アカウントでログインしました", flash[:notice]

    get dashboard_articles_path
    assert_response :success
  end

  test "新しいメールアドレスなら、確認済みのアカウントが作られる" do
    assert_difference -> { User.count }, 1 do
      get user_github_omniauth_callback_path, env: { "omniauth.auth" => omniauth_hash("newcomer@example.com") }
    end
    assert_equal "アカウントを作成しました", flash[:notice]
    assert User.find_by!(email: "newcomer@example.com").confirmed?

    get dashboard_articles_path
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
