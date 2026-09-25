require "test_helper"

class Dashboard::CommentsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "自分の記事のコメントはshowできる" do
    sign_in users(:blogger)
    get dashboard_comment_path(comments(:one))

    assert_response :success
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
