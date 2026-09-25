require "test_helper"

class CommentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @article = articles(:published_ja)
  end

  test "有効な入力でコメントが作成され、記事ページへリダイレクトされる" do
    assert_difference("Comment.count", 1) do
      post article_comments_path(@article.user.username, @article, locale: "ja"), params: {
        comment: { author_name: "テスト太郎", content: "テストコメント本文" }
      }
    end

    assert_redirected_to user_article_path(@article.user.username, @article, locale: "ja")
    assert Comment.last.article == @article
  end

  test "名前が空の場合はコメントが作成されず、エラーが分かる形で表示される" do
    assert_no_difference("Comment.count") do
      post article_comments_path(@article.user.username, @article, locale: "ja"), params: {
        comment: { author_name: "", content: "テストコメント本文" }
      }
    end

    assert_redirected_to user_article_path(@article.user.username, @article, locale: "ja")
    assert flash[:alert].present?
  end

  test "本文が空の場合はコメントが作成されず、エラーが分かる形で表示される" do
    assert_no_difference("Comment.count") do
      post article_comments_path(@article.user.username, @article, locale: "ja"), params: {
        comment: { author_name: "テスト太郎", content: "" }
      }
    end

    assert_redirected_to user_article_path(@article.user.username, @article, locale: "ja")
    assert flash[:alert].present?
  end

  test "存在しない記事IDの場合は404になる" do
    assert_no_difference("Comment.count") do
      post article_comments_path(@article.user.username, -1, locale: "ja"), params: {
        comment: { author_name: "テスト太郎", content: "テストコメント本文" }
      }
    end

    assert_response :not_found
  end

  test "未公開記事に対してコメントを投稿すると404になり、コメントも作成されない" do
    draft = articles(:draft_ja)

    assert_no_difference("Comment.count") do
      post article_comments_path(draft.user.username, draft, locale: "ja"), params: {
        comment: { author_name: "テスト太郎", content: "テストコメント本文" }
      }
    end

    assert_response :not_found
  end
end
