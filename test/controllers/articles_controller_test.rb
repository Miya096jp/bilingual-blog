require "test_helper"

class ArticlesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  # OAuthの資格情報がない環境ではDeviseがomniauth用のURLヘルパーを定義せず、
  # レイアウトのログインモーダルが描画できないため、このコントローラに限りダミーを定義する
  if Devise.omniauth_configs.empty?
    ArticlesController.helper(Module.new { def omniauth_authorize_path(*) = "#" })
  end

  test "未ログインで他人の未公開記事の詳細にアクセスすると404になる" do
    article = articles(:draft_ja)

    get user_article_path(article.user.username, article, locale: "ja")

    assert_response :not_found
  end

  test "別のログインユーザーで他人の未公開記事の詳細にアクセスすると404になる" do
    article = articles(:draft_ja)
    sign_in users(:one)

    get user_article_path(article.user.username, article, locale: "ja")

    assert_response :not_found
  end

  test "所有者本人でログインして自分の未公開記事の詳細にアクセスすると200になる" do
    article = articles(:draft_ja)
    sign_in article.user

    get user_article_path(article.user.username, article, locale: "ja")

    assert_response :success
  end

  test "未ログインで公開済みの記事の詳細にアクセスすると200になる" do
    article = articles(:published_ja)

    get user_article_path(article.user.username, article, locale: "ja")

    assert_response :success
  end

  test "ユーザーAのブログURLにユーザーBの公開済み記事のidを入れてアクセスすると404になる" do
    owner_a = users(:blogger)
    article_of_b = articles(:search_target_ja)

    get user_article_path(owner_a.username, article_of_b, locale: "ja")

    assert_response :not_found
  end

  test "記事一覧に他ユーザーの未公開記事が含まれない" do
    draft = articles(:draft_ja)

    get user_articles_path(draft.user.username, locale: "ja")

    assert_response :success
    assert_no_match draft.title, response.body
  end

  test "所有者本人が自分の未公開記事を表示したときは、いいねボタンとコメント欄が表示されない" do
    article = articles(:draft_ja)
    sign_in article.user

    get user_article_path(article.user.username, article, locale: "ja")

    assert_response :success
    assert_select "#like_button_#{article.id}", count: 0
    assert_select ".comment-section", count: 0
    assert_select "form[action=?]", article_comments_path(article.user.username, article, locale: "ja"), count: 0
  end

  test "公開済みの記事には、いいねボタンとコメント欄が表示される" do
    article = articles(:published_ja)

    get user_article_path(article.user.username, article, locale: "ja")

    assert_select "#like_button_#{article.id}"
    assert_select "form[action=?]", article_comments_path(article.user.username, article, locale: "ja")
  end

  test "コメント投稿者のWebサイトへのリンクにはrel=\"nofollow ugc noopener\"が付く" do
    article = articles(:published_ja)
    comment = comments(:one)

    get user_article_path(article.user.username, article, locale: "ja")

    assert_select "a[href=?][rel=?]", comment.website, "nofollow ugc noopener", text: comment.author_name
  end

  test "コメントフォームのハニーポット欄は自動入力されない設定で画面外に置かれる" do
    article = articles(:published_ja)

    get user_article_path(article.user.username, article, locale: "ja")

    assert_select "[aria-hidden=true] input[name=?][tabindex=?][autocomplete=?]", "comment[homepage]", "-1", "off"
  end

  test "停止中のユーザーの記事一覧・記事詳細は、存在しないユーザーと同じ扱いになる" do
    article = articles(:published_ja)
    article.user.suspend!

    get user_articles_path(article.user.username, locale: "ja")
    assert_redirected_to root_path(locale: "ja")
    assert_equal "ユーザーが見つかりません", flash[:alert]

    get user_article_path(article.user.username, article, locale: "ja")
    assert_redirected_to root_path(locale: "ja")
    assert_equal "ユーザーが見つかりません", flash[:alert]
  end

  test "停止を解除すると、記事一覧・記事詳細が元どおり表示される" do
    article = articles(:published_ja)
    article.user.suspend!
    article.user.restore!

    get user_articles_path(article.user.username, locale: "ja")
    assert_response :success

    get user_article_path(article.user.username, article, locale: "ja")
    assert_response :success
  end
end
