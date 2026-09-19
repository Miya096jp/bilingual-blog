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

  test "タイトル検索で日本語・英語どちらのタイトルでもヒットする" do
    sign_in users(:one)
    get dashboard_articles_path(q: "Study Notes")

    assert_response :success
    assert_match articles(:search_target_ja).title, response.body
    assert_no_match articles(:mixed_status_ja).title, response.body
  end

  test "絞り込みチップで公開ペアのみ表示できる" do
    sign_in users(:one)
    get dashboard_articles_path(status: "published")

    assert_response :success
    assert_match articles(:search_target_ja).title, response.body
    assert_no_match articles(:mixed_status_ja).title, response.body
  end

  test "絞り込みチップで下書きを含むペアのみ表示できる" do
    sign_in users(:one)
    get dashboard_articles_path(status: "draft")

    assert_response :success
    assert_match articles(:mixed_status_ja).title, response.body
    assert_no_match articles(:search_target_ja).title, response.body
  end

  test "絞り込みチップで翻訳なしのペアのみ表示できる" do
    sign_in users(:one)
    get dashboard_articles_path(status: "no_translation")

    assert_response :success
    assert_match articles(:en_original_no_translation).title, response.body
    assert_no_match articles(:search_target_ja).title, response.body
  end

  test "既定の並び替えで英語だけ更新したペアが上位に表示される" do
    sign_in users(:one)
    get dashboard_articles_path

    assert_response :success
    en_updated_position = response.body.index(articles(:en_updated_ja).title)
    search_target_position = response.body.index(articles(:search_target_ja).title)

    assert en_updated_position < search_target_position
  end

  test "並び替えを作成が古い順にすると原文のcreated_at昇順で表示される" do
    sign_in users(:one)
    get dashboard_articles_path(sort: "created_asc")

    assert_response :success
    en_updated_position = response.body.index(articles(:en_updated_ja).title)
    search_target_position = response.body.index(articles(:search_target_ja).title)

    assert en_updated_position < search_target_position
  end

  test "検索・絞り込み・並び替えの状態がページングリンクに引き継がれる" do
    25.times do |i|
      Article.create!(
        title: "公開記事 #{i}",
        content: "本文 #{i}",
        locale: "ja",
        status: "published",
        user: users(:one)
      )
    end

    sign_in users(:one)
    get dashboard_articles_path(status: "published", sort: "created_asc")

    assert_response :success
    assert_select "a[href*='status=published'][href*='sort=created_asc']"
  end

  test "検索結果が0件のときは条件を外す導線付きの案内が表示される" do
    sign_in users(:one)
    get dashboard_articles_path(q: "該当しない検索語")

    assert_response :success
    assert_match "条件に合う記事がありません", response.body
    assert_select "a[href=?]", dashboard_articles_path, text: "絞り込みを解除"
  end
end
