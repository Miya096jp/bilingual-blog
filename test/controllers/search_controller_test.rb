require "test_helper"

class SearchControllerTest < ActionDispatch::IntegrationTest
  # OAuthの資格情報がない環境ではDeviseがomniauth用のURLヘルパーを定義せず、
  # レイアウトのログインモーダルが描画できないため、このコントローラに限りダミーを定義する
  if Devise.omniauth_configs.empty?
    SearchController.helper(Module.new { def omniauth_authorize_path(*) = "#" })
  end

  test "1件以上ヒットする検索で、ヒットした記事のタイトルが表示される" do
    article = articles(:search_target_ja)

    get user_search_path(article.user.username, locale: "ja", q: "Ruby")

    assert_response :success
    assert_select "h2 a", text: article.title
  end

  test "カテゴリとタグのある記事がヒットしても表示される" do
    article = articles(:published_ja)
    assert article.category.present?
    assert article.tags.any?

    get user_search_path(article.user.username, locale: "ja", q: "公開記事")

    assert_response :success
    assert_select "h2 a", text: article.title
  end

  test "検索結果のカテゴリ・タグのリンクが、記事一覧の該当する絞り込みを指す" do
    article = articles(:published_ja)
    username = article.user.username

    get user_search_path(username, locale: "ja", q: "公開記事")

    assert_response :success
    assert_select "a[href=?]", user_articles_path(username, locale: "ja", category_id: article.category.id)
    article.tags.each do |tag|
      assert_select "a[href=?]", user_articles_path(username, locale: "ja", tag_id: tag.id)
    end
  end

  test "検索結果で、翻訳が下書きの記事に翻訳へのリンクが出ない" do
    article = articles(:mixed_status_ja)
    draft_translation = articles(:mixed_status_en)

    get user_search_path(article.user.username, locale: "ja", q: "混在ステータス")

    assert_response :success
    assert_select "h2 a", text: article.title
    assert_select "a[href=?]", user_article_path(draft_translation.user.username, draft_translation.id, locale: "en"), count: 0
  end

  test "検索結果で、翻訳が公開されている記事には翻訳へのリンクが出る" do
    article = articles(:en_updated_ja)
    translation = articles(:en_updated_en)

    get user_search_path(article.user.username, locale: "ja", q: "英語だけ更新")

    assert_response :success
    assert_select "a[href=?]", user_article_path(translation.user.username, translation.id, locale: "en")
  end
end
