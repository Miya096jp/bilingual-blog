require "test_helper"

# 公開ページのヘッダーのログインボタンとダッシュボードへのリンクは、
# ほかのヘッダーの文言と同じくロケールに合わせて表示する
class HeaderAuthLinksTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  # OAuthの資格情報がない環境ではDeviseがomniauth用のURLヘルパーを定義せず、
  # レイアウトのログインモーダルが描画できないため、ダミーを定義する
  if Devise.omniauth_configs.empty?
    ApplicationController.helper(Module.new { def omniauth_authorize_path(*) = "#" })
  end

  # ログインモーダルを開くボタン
  LOGIN_BUTTON = "button[data-action='click->auth-modal#showModal']".freeze

  setup do
    @user = users(:one)
  end

  { "ja" => "ログイン", "en" => "Log in" }.each do |locale, label|
    test "ログアウト状態の #{locale} のヘッダーに、ログインボタンが「#{label}」で出る" do
      get user_articles_path(@user.username, locale: locale)

      assert_response :success
      # PC 用とモバイルメニュー用の2か所
      assert_select LOGIN_BUTTON, text: label, count: 2
      assert_no_match(/Sign in/, response.body)
    end
  end

  { "ja" => "ダッシュボード", "en" => "Dashboard" }.each do |locale, label|
    test "ログイン状態の #{locale} のヘッダーに、ダッシュボードへのリンクが「#{label}」で出る" do
      sign_in @user

      get user_articles_path(@user.username, locale: locale)

      assert_response :success
      # PC 用とモバイルメニュー用の2か所。リンクには ?locale= が付くため前方一致で探す
      assert_select "a[href^='#{dashboard_articles_path}']", text: label, count: 2
    end
  end

  test "ログイン状態の ja のヘッダーに「Dashboard」が残っていない" do
    sign_in @user

    get user_articles_path(@user.username, locale: "ja")

    assert_response :success
    assert_no_match(/Dashboard/, response.body)
  end
end
