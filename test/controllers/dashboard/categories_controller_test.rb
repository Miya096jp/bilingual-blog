require "test_helper"

class Dashboard::CategoriesControllerTest < ActionDispatch::IntegrationTest
  test "未ログインでカテゴリの詳細にアクセスすると、ログイン画面へリダイレクトされる" do
    get dashboard_category_path(categories(:programming_ja))

    assert_redirected_to new_user_session_path
  end
end
