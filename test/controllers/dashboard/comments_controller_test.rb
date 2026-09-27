require "test_helper"

class Dashboard::CommentsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "自分の記事のコメントはshowできる" do
    sign_in users(:blogger)
    get dashboard_comment_path(comments(:one))

    assert_response :success
  end

  test "showの投稿者ウェブサイトへのリンクにはnofollow ugc noopenerが付く" do
    sign_in users(:blogger)
    get dashboard_comment_path(comments(:one))

    assert_select "a[href=?][rel=?]", comments(:one).website, "nofollow ugc noopener"
  end

  test "showの記事タイトルは公開側の記事ページにリンクする" do
    sign_in users(:blogger)
    article = comments(:one).article
    get dashboard_comment_path(comments(:one))

    assert_select "a[href=?]", user_article_path(article.user.username, article.id, locale: article.locale), text: article.title
  end

  test "showに削除と一覧に戻るのリンクがある" do
    sign_in users(:blogger)
    get dashboard_comment_path(comments(:one))

    assert_select "a[href=?][data-turbo-method=delete][data-turbo-confirm]", dashboard_comment_path(comments(:one)), text: "削除"
    assert_select "a[href=?]", dashboard_comments_path, text: "一覧に戻る"
  end

  test "自分の記事のコメントはdestroyできる" do
    sign_in users(:blogger)

    assert_difference("Comment.count", -1) do
      delete dashboard_comment_path(comments(:one))
    end

    assert_redirected_to dashboard_comments_path
  end

  test "他ユーザーの記事のコメントはshowすると404になる" do
    sign_in users(:one)
    get dashboard_comment_path(comments(:one))

    assert_response :not_found
  end

  test "他ユーザーの記事のコメントはdestroyすると404になり削除されない" do
    sign_in users(:one)

    assert_no_difference("Comment.count") do
      delete dashboard_comment_path(comments(:one))
    end

    assert_response :not_found
  end
end
