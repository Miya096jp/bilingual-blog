require "test_helper"

class LikesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @article = articles(:published_ja)
  end

  test "ログイン済みユーザーがいいねすると記事ページへリダイレクトされる" do
    sign_in users(:admin)

    assert_difference("Like.count", 1) do
      post user_article_likes_path(@article.user.username, @article, locale: "ja")
    end

    assert_redirected_to user_article_path(@article.user.username, @article, locale: "ja")
    assert_equal users(:admin), Like.last.user
    assert_nil Like.last.visitor_token
  end

  test "ログイン済みユーザーは再度リクエストするといいねが取り消される" do
    sign_in users(:admin)
    post user_article_likes_path(@article.user.username, @article, locale: "ja")

    assert_difference("Like.count", -1) do
      delete user_article_like_path(@article.user.username, @article, locale: "ja")
    end
  end

  test "未ログインの訪問者がいいねすると匿名Likeが作成されCookieが発行される" do
    assert_difference("Like.count", 1) do
      post user_article_likes_path(@article.user.username, @article, locale: "ja")
    end

    like = Like.last
    assert_nil like.user_id
    assert like.visitor_token.present?
    assert cookies[:visitor_token].present?
  end

  test "未ログインの訪問者が同じCookieで再度リクエストするといいねが取り消される" do
    post user_article_likes_path(@article.user.username, @article, locale: "ja")

    assert_difference("Like.count", -1) do
      delete user_article_like_path(@article.user.username, @article, locale: "ja")
    end
  end

  test "未ログインの訪問者がCookieなしで取り消しリクエストしても他人のいいねは消えない" do
    assert_no_difference("Like.count") do
      delete user_article_like_path(@article.user.username, @article, locale: "ja")
    end
  end

  test "いいねするとarticleのlikes_countが増える" do
    assert_difference(-> { @article.reload.likes_count }, 1) do
      post user_article_likes_path(@article.user.username, @article, locale: "ja")
    end
  end

  test "未公開記事へのいいねは404になり、Likeも作成されない" do
    draft = articles(:draft_ja)

    assert_no_difference("Like.count") do
      post user_article_likes_path(draft.user.username, draft, locale: "ja")
    end

    assert_response :not_found
  end

  test "所有者本人でも自分の未公開記事へのいいねは404になる" do
    draft = articles(:draft_ja)
    sign_in draft.user

    assert_no_difference("Like.count") do
      post user_article_likes_path(draft.user.username, draft, locale: "ja")
    end

    assert_response :not_found
  end
end
