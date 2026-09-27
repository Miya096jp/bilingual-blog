require "test_helper"

# パスワードの長さは新規作成時と変更時にだけ検証されるため、
# 最小長を上げる前に短いパスワードで登録したユーザーも、そのまま使い続けられることを確かめる。
class PasswordLengthTest < ActionDispatch::IntegrationTest
  test "最小長より短いパスワードの既存ユーザーも、パスワードでログインできる" do
    user = users(:short_password)

    post user_session_path, params: { user: { email: user.email, password: "pass123" } }

    assert_redirected_to root_path
    get dashboard_articles_path
    assert_response :success
  end

  test "最小長より短いパスワードの既存ユーザーも、プロフィールを更新できる" do
    user = users(:short_password)
    post user_session_path, params: { user: { email: user.email, password: "pass123" } }

    patch dashboard_profile_path, params: { user: { nickname_ja: "新しいニックネーム" } }

    assert_redirected_to edit_dashboard_profile_path
    assert_equal "新しいニックネーム", user.reload.nickname_ja
  end
end
