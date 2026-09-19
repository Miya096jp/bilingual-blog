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

  test "一覧の表ヘッダーとフォームのラベルが日本語で表示される" do
    get dashboard_categories_path
    assert_select "th", text: "カテゴリ名"
    assert_select "th", text: "操作"
    assert_select "a", text: "カテゴリを作成"

    get new_dashboard_category_path
    assert_select "label", text: "カテゴリ名"
    assert_select "input[type=submit][value=?]", "カテゴリを作成"

    get dashboard_comments_path
    assert_select "th", text: "投稿者"
    assert_select "th", text: "コメント内容"

    get edit_dashboard_blog_setting_path
    assert_select "label", text: "ブログタイトル"
    assert_select "input[type=submit][value=?]", "保存"
  end

  test "記事編集フォームのセレクトが日本語で表示される" do
    get new_dashboard_article_path

    assert_select "select[name=?] option", "article[status]", text: "下書き"
    assert_select "select[name=?] option", "article[status]", text: "公開"
    assert_select "select[name=?] option", "article[locale]", text: "日本語"
    assert_select "select[name=?] option", "article[locale]", text: "英語"
  end
end
