require "test_helper"

# Devise が送るメールは、利用者のロケールに関わらず日本語で送る
class UserMailerTest < ActionMailer::TestCase
  ENGLISH_DEFAULTS = [ "Hello", "Welcome", "Someone has requested", "Change my password",
                       "Confirm my account", "We're contacting you" ].freeze

  setup do
    @user = users(:one)
  end

  test "パスワード再設定のメールが日本語で、トークン付きのリンクを含む" do
    mail = Devise.mailer.reset_password_instructions(@user, "TOKEN")

    assert_equal "【Dual Pascal】パスワード再設定のご案内", mail.subject
    assert_japanese_mail mail,
      "パスワード再設定のリクエストを受け付けました",
      "このリンクの有効期限は6時間です",
      "http://example.com/users/password/edit?reset_password_token=TOKEN"
    assert_includes mail.html_part.decoded, "パスワードを再設定する"
  end

  test "メールアドレス確認のメールが日本語で、トークン付きのリンクを含む" do
    mail = Devise.mailer.confirmation_instructions(@user, "TOKEN")

    assert_equal "【Dual Pascal】メールアドレスの確認", mail.subject
    assert_japanese_mail mail,
      "Dual Pascal にご登録いただきありがとうございます",
      "http://example.com/users/confirmation?confirmation_token=TOKEN"
    assert_includes mail.html_part.decoded, "メールアドレスを確認する"
  end

  test "メールアドレス変更の通知が日本語で、お問い合わせのURLを含む" do
    @user.unconfirmed_email = "new@example.com"
    mail = Devise.mailer.email_changed(@user)

    assert_equal "【Dual Pascal】メールアドレス変更のお知らせ", mail.subject
    assert_japanese_mail mail,
      "new@example.com",
      "http://example.com/ja/contacts/new"
  end

  test "パスワード変更の通知が日本語で、お問い合わせのURLを含む" do
    mail = Devise.mailer.password_change(@user)

    assert_equal "【Dual Pascal】パスワード変更のお知らせ", mail.subject
    assert_japanese_mail mail,
      "パスワードが変更されました",
      "http://example.com/ja/contacts/new"
  end

  test "ロケールが en のときに作っても日本語で、呼び出し元のロケールは変えない" do
    I18n.with_locale(:en) do
      mail = Devise.mailer.reset_password_instructions(@user, "TOKEN")

      assert_equal "【Dual Pascal】パスワード再設定のご案内", mail.subject
      assert_japanese_mail mail, "パスワード再設定のリクエストを受け付けました"
      assert_equal :en, I18n.locale
    end
  end

  test "ロケールが en のときにパスワード再設定を送っても、日本語で届く" do
    I18n.with_locale(:en) { @user.send_reset_password_instructions }

    mail = ActionMailer::Base.deliveries.last
    assert_equal [ @user.email ], mail.to
    assert_equal "【Dual Pascal】パスワード再設定のご案内", mail.subject
  end

  test "パスワードを変更すると、変更の通知が届く" do
    @user.update!(password: "newpassword123", password_confirmation: "newpassword123")

    mail = ActionMailer::Base.deliveries.last
    assert_equal [ @user.email ], mail.to
    assert_equal "【Dual Pascal】パスワード変更のお知らせ", mail.subject
  end

  test "メールアドレスを変更すると、元のアドレスに変更の通知が届く" do
    old_email = @user.email
    @user.update!(email: "new@example.com")

    mail = ActionMailer::Base.deliveries.find { |m| m.subject == "【Dual Pascal】メールアドレス変更のお知らせ" }
    assert mail, "メールアドレス変更の通知が送られていない"
    assert_equal [ old_email ], mail.to
  end

  private

  # HTML・テキストの両方に、宛名・署名・指定した文言が含まれ、英語の既定の文言が含まれないこと
  def assert_japanese_mail(mail, *phrases)
    assert mail.multipart?, "マルチパートで送られていない"

    [ mail.html_part, mail.text_part ].each do |part|
      assert part, "HTMLまたはテキストのパートがない"
      body = part.decoded
      assert_includes body, "#{@user.username} 様"
      assert_includes body, "http://example.com/"
      phrases.each { |phrase| assert_includes body, phrase }
      ENGLISH_DEFAULTS.each { |english| assert_not_includes body, english }
    end
  end
end
