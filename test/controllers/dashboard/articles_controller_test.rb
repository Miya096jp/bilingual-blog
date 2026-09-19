require "test_helper"

class Dashboard::ArticlesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:blogger)
  end

  test "一覧に言語ごとの件数と公開・下書きの内訳が表示される" do
    sign_in @user
    get dashboard_articles_path

    assert_response :success
    assert_match "日本語 3 件(公開 2・下書き 1)", response.body
    assert_match "英語 1 件(公開 1・下書き 0)", response.body
  end

  test "翻訳がある記事は両言語のタイトルがそれぞれの編集画面へリンクされる" do
    sign_in @user
    get dashboard_articles_path

    assert_response :success
    assert_select "a[href=?]", edit_dashboard_article_path(articles(:published_ja)), text: articles(:published_ja).title
    assert_select "a[href=?]", edit_dashboard_article_translation_path(articles(:published_ja)), text: articles(:published_en).title
  end

  test "翻訳がない記事の側には翻訳作成へのリンクのみが表示される" do
    sign_in @user
    get dashboard_articles_path

    assert_response :success
    assert_select "a[href=?]", new_dashboard_article_translation_path(articles(:draft_ja)), text: /翻訳を作成/
    assert_select "a[href=?]", new_dashboard_article_translation_path(articles(:rails_article)), text: /翻訳を作成/
  end

  test "各言語セルに書き出しアイコンが言語のわかるaria-label付きで表示される" do
    sign_in @user
    get dashboard_articles_path

    assert_response :success
    assert_select "a[href=?][aria-label=?]", dashboard_article_export_path(articles(:published_ja)), "日本語記事をMarkdownで書き出し"
    assert_select "a[href=?][aria-label=?]", dashboard_article_export_path(articles(:published_en)), "英語記事をMarkdownで書き出し"
    # 翻訳が存在するのは blogger の3ペア中1ペアのみ
    assert_select "a[aria-label=?]", "英語記事をMarkdownで書き出し", count: 1
  end

  test "カテゴリ未設定の記事は補助テキストに「カテゴリなし」と表示される" do
    sign_in @user
    get dashboard_articles_path

    assert_response :success
    assert_match "カテゴリなし", response.body
  end

  test "補助テキストの日付はupdated_atを西暦から表示する" do
    sign_in @user
    get dashboard_articles_path

    assert_response :success
    assert_match articles(:published_ja).updated_at.strftime("%Y-%m-%d"), response.body
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
