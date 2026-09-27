require "test_helper"

class AuthHeadingTest < ActionDispatch::IntegrationTest
  # OAuthの資格情報がない環境ではDeviseがomniauth用のURLヘルパーを定義せず、
  # ソーシャルログインのボタンが描画できないため、ダミーを定義する
  if Devise.omniauth_configs.empty?
    ApplicationController.helper(Module.new { def omniauth_authorize_path(*) = "#" })
  end

  # 新規登録・ログインのフォームはモーダル内の turbo-frame からだけ読み込まれる
  FRAME_HEADERS = { "Turbo-Frame" => "auth_form_frame" }.freeze

  test "新規登録フォームの見出しがロケールに合わせて表示される" do
    get new_user_registration_path, headers: FRAME_HEADERS
    assert_select "h3", text: "アカウントを作成"

    get new_user_registration_path(locale: "en"), headers: FRAME_HEADERS
    assert_select "h3", text: "Create account"
  end

  test "ログインフォームの見出しがロケールに合わせて表示される" do
    get new_user_session_path, headers: FRAME_HEADERS
    assert_select "h3", text: "ログイン"

    get new_user_session_path(locale: "en"), headers: FRAME_HEADERS
    assert_select "h3", text: "Sign in"
  end
end
