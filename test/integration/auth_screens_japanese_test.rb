require "test_helper"

# 認証まわりの画面は、メールと同じく訪問者のロケールに関わらず日本語で表示する
class AuthScreensJapaneseTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  # OAuthの資格情報がない環境ではDeviseがomniauth用のURLヘルパーを定義せず、
  # ソーシャルログインのボタンが描画できないため、ダミーを定義する
  if Devise.omniauth_configs.empty?
    ApplicationController.helper(Module.new { def omniauth_authorize_path(*) = "#" })
  end

  # 新規登録・ログインなどのフォームはモーダル内の turbo-frame からだけ読み込まれる
  FRAME_HEADERS = { "Turbo-Frame" => "auth_form_frame" }.freeze

  # 画面に残っていた英語の文言
  ENGLISH_WORDS = /Sign in|Sign up|Log in|Continue with|Username|Email|Password|password\?|Already have|Don't have|Remember your|Reset|Resend|Change|Update|Cancel|Back/

  test "新規登録フォームが en でも日本語で表示される" do
    get new_user_registration_path(locale: "en"), headers: FRAME_HEADERS

    assert_select "h3", text: "アカウントを作成"
    assert_select "button", text: "GitHubでログイン"
    assert_select "button", text: "Googleでログイン"
    assert_select "span", text: "または"
    assert_select "input[placeholder=?]", "ユーザー名"
    assert_select "input[placeholder=?]", "メールアドレス"
    assert_select "input[placeholder=?]", "パスワード（8文字以上）"
    assert_select "input[placeholder=?]", "パスワード（確認）"
    assert_select "input[type=submit][value=?]", "アカウントを作成"
    assert_select "span", text: "すでにアカウントをお持ちの方"
    assert_select "a[href=?]", new_user_session_path, text: "ログイン"
    assert_no_match ENGLISH_WORDS, response.body
  end

  test "ログインフォームが en でも日本語で表示される" do
    get new_user_session_path(locale: "en"), headers: FRAME_HEADERS

    assert_select "h3", text: "ログイン"
    assert_select "button", text: "GitHubでログイン"
    assert_select "input[placeholder=?]", "メールアドレス"
    assert_select "input[placeholder=?]", "パスワード"
    assert_select "input[type=submit][value=?]", "ログイン"
    assert_select "a[href=?]", new_user_password_path, text: "パスワードを忘れた方"
    assert_select "span", text: "アカウントをお持ちでない方"
    assert_select "a[href=?]", new_user_registration_path, text: "新規登録"
    assert_no_match ENGLISH_WORDS, response.body
  end

  test "パスワード再設定(メール入力)のフォームが en でも日本語で表示される" do
    get new_user_password_path(locale: "en"), headers: FRAME_HEADERS

    assert_select "h3", text: "パスワード再設定"
    assert_select "input[placeholder=?]", "メールアドレス"
    assert_select "p", text: "登録済みのメールアドレスであれば、パスワード再設定用のリンクを送信します。"
    assert_select "input[type=submit][value=?]", "再設定メールを送信"
    assert_select "span", text: "パスワードを覚えている方"
    assert_select "a[href=?]", new_user_session_path, text: "ログイン"
    assert_select "span", text: "アカウントをお持ちでない方"
    assert_select "a[href=?]", new_user_registration_path, text: "新規登録"
    assert_no_match ENGLISH_WORDS, response.body
  end

  test "新しいパスワードの入力画面が en でも日本語で表示される" do
    token = users(:one).send(:set_reset_password_token)

    get edit_user_password_path(reset_password_token: token, locale: "en")

    # 共通レイアウトのヘッダーは対象外なので、フォームの枠の中だけを確認する
    assert_select ".max-w-md" do |container|
      assert_select "h2", text: "新しいパスワードの設定"
      assert_select "label[for=user_password]", text: "新しいパスワード"
      assert_select "p", text: "（8文字以上）"
      assert_select "label[for=user_password_confirmation]", text: "新しいパスワード（確認）"
      assert_select "input[type=submit][value=?]", "パスワードを変更"
      assert_select "a", text: "ログインに戻る"
      assert_no_match ENGLISH_WORDS, container.to_html
    end
  end

  test "確認メールの再送画面が en でも日本語で表示される" do
    get new_user_confirmation_path(locale: "en")

    assert_select "form[action=?]", user_confirmation_path do |form|
      assert_select "label[for=user_email]", text: "メールアドレス"
      assert_select "input[type=submit][value=?]", "確認メールを再送"
      assert_no_match ENGLISH_WORDS, form.to_html
    end
    assert_select "h2", text: "確認メールの再送"
    assert_select "a[href=?]", new_user_session_path, text: "ログイン"
    assert_select "a[href=?]", new_user_registration_path, text: "新規登録"
    assert_select "a[href=?]", new_user_password_path, text: "パスワードを忘れた方"
    assert_select "button", text: "GitHubでログイン"
    assert_select "button", text: "Googleでログイン"
  end

  test "アカウント設定画面が en でも日本語で表示される" do
    sign_in users(:one)

    get edit_user_registration_path(locale: "en"), headers: FRAME_HEADERS

    assert_select "h2", text: "アカウント設定"
    assert_select "form#edit_user" do |form|
      assert_select "label[for=user_email]", text: "メールアドレス"
      assert_select "label[for=user_password]", text: "パスワード"
      assert_select "label[for=user_password_confirmation]", text: "パスワード（確認）"
      assert_select "label[for=user_current_password]", text: "現在のパスワード"
      assert_select "input[type=submit][value=?]", "更新"
      assert_no_match ENGLISH_WORDS, form.to_html
    end
    assert_select "h3", text: "アカウントの削除"
    assert_select "button[data-turbo-confirm=?]", "本当に削除しますか？", text: "アカウントを削除"
    assert_select "a", text: "戻る"
  end
end
