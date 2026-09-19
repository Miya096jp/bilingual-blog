require "test_helper"

class Dashboard::PageTitlesTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in users(:blogger)
  end

  test "ダッシュボードの各画面の見出しが日本語で表示される" do
    {
      dashboard_articles_path => "記事",
      edit_dashboard_profile_path => "プロフィール",
      dashboard_categories_path => "カテゴリ",
      new_dashboard_category_path => "カテゴリを作成",
      edit_dashboard_category_path(categories(:programming_ja)) => "カテゴリを編集",
      dashboard_comments_path => "コメント",
      dashboard_comment_path(comments(:one)) => "コメント詳細",
      edit_dashboard_blog_setting_path => "ブログ設定",
      dashboard_article_path(articles(:published_ja)) => "記事の詳細",
      dashboard_article_translation_path(articles(:published_ja)) => "翻訳記事の詳細",
      dashboard_delete_account_confirmation_path => "アカウントの削除"
    }.each do |path, title|
      get path

      assert_response :success, "#{path} が表示できない"
      assert_select ".container h1", { text: title, count: 1 }, "#{path} の見出しが #{title} ではない"
    end
  end

  test "見出しのスタイルが記事一覧の見出しと揃っている" do
    get dashboard_articles_path
    assert_select ".container h1.text-2xl.font-bold.text-\\[\\#1B1B19\\]", text: "記事"

    get dashboard_categories_path
    assert_select ".container h1.text-2xl.font-bold.text-\\[\\#1B1B19\\].mb-6", text: "カテゴリ"
  end

  test "アカウント削除の見出しだけは危険操作として赤で表示される" do
    get dashboard_delete_account_confirmation_path

    assert_select ".container h1.text-2xl.font-bold.text-red-600.mb-6", text: "アカウントの削除"
  end
end
