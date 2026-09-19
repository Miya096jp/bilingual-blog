require "test_helper"

class DashboardNavigationTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:one)
    @admin = users(:admin)
  end

  test "一般ユーザーには通常のナビ項目が見え、管理者専用リンクは見えない" do
    sign_in @user
    get dashboard_articles_path

    assert_response :success
    %w[記事一覧 カテゴリ コメント アナリティクス プロフィール ブログ設定 ブログを見る ログアウト].each do |label|
      assert_match label, response.body
    end
    assert_match @user.username, response.body

    assert_no_match(/ユーザー管理/, response.body)
    assert_no_match(/全記事管理/, response.body)

    assert_select "a[aria-current='page']", text: "記事一覧"
  end

  test "画面を移動すると現在地のハイライトが切り替わる" do
    sign_in @user
    get dashboard_categories_path

    assert_response :success
    assert_select "a[aria-current='page']", text: "カテゴリ"
    assert_select "a[aria-current='page']", text: "記事一覧", count: 0
  end

  test "管理者には管理者専用リンクが見える" do
    sign_in @admin
    get dashboard_articles_path

    assert_response :success
    assert_select "a[href=?]", admin_users_path, text: "ユーザー管理"
    assert_select "a[href=?]", admin_articles_path, text: "全記事管理"
  end
end
