require "test_helper"

class AccountEnumerationTest < ActionDispatch::IntegrationTest
  test "パスワード再設定の依頼は、メールアドレスの登録有無にかかわらず同じ応答になる" do
    assert_emails 1 do
      post user_password_path, params: { user: { email: users(:one).email } }
    end
    registered = [ response.status, response.location, flash[:notice] ]

    assert_no_emails do
      post user_password_path, params: { user: { email: "unknown@example.com" } }
    end
    unregistered = [ response.status, response.location, flash[:notice] ]

    assert_equal registered, unregistered
    assert_equal I18n.t("devise.passwords.send_paranoid_instructions"), flash[:notice]
  end

  test "確認メールの再送は、メールアドレスの登録有無にかかわらず同じ応答になる" do
    user = users(:unconfirmed)

    assert_emails 1 do
      post user_confirmation_path, params: { user: { email: user.email } }
    end
    registered = [ response.status, response.location, flash[:notice] ]

    assert_no_emails do
      post user_confirmation_path, params: { user: { email: "unknown@example.com" } }
    end
    unregistered = [ response.status, response.location, flash[:notice] ]

    assert_equal registered, unregistered
    assert_equal I18n.t("devise.confirmations.send_paranoid_instructions"), flash[:notice]
  end
end
