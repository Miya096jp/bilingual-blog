require "test_helper"

class Dashboard::ArticlesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:blogger)
  end

  test "一覧に件数と公開・下書きの内訳が表示される" do
    sign_in @user
    get dashboard_articles_path

    assert_response :success
    assert_match "3 件(公開 2・下書き 1)", response.body
  end

  test "翻訳がある記事は両言語のタイトルがそれぞれの編集画面へリンクされる" do
    sign_in @user
    get dashboard_articles_path

    assert_response :success
    assert_select "a[href=?]", edit_dashboard_article_path(articles(:published_ja)), text: articles(:published_ja).title
    assert_select "a[href=?]", edit_dashboard_article_translation_path(articles(:published_ja)), text: articles(:published_en).title
  end

  test "翻訳がない記事には翻訳作成へのリンクが表示される" do
    sign_in @user
    get dashboard_articles_path

    assert_response :success
    assert_select "a[href=?]", new_dashboard_article_translation_path(articles(:draft_ja)), text: /翻訳を作成/
  end

  test "操作メニューに存在する言語分のMarkdown書き出しリンクが表示される" do
    sign_in @user
    get dashboard_articles_path

    assert_response :success
    assert_select "a[href=?]", dashboard_article_export_path(articles(:published_ja)), text: "日本語を書き出し"
    assert_select "a[href=?]", dashboard_article_export_path(articles(:published_en)), text: "英語を書き出し"
    assert_select "a[href=?]", dashboard_article_export_path(articles(:rails_article)), text: "英語を書き出し", count: 0
  end

  test "記事が0件のときは案内メッセージが表示される" do
    sign_in users(:two)
    get dashboard_articles_path

    assert_response :success
    assert_match "まだ記事がありません", response.body
  end

  test "他のユーザーの記事は一覧に表示されない" do
    sign_in @user
    get dashboard_articles_path

    assert_response :success
    assert_no_match articles(:test_article).title, response.body
  end
end
