require "test_helper"

class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @admin = users(:admin)
    sign_in @admin
  end

  test "管理者は一般ユーザーを停止・復旧できる" do
    user = users(:blogger)

    patch admin_user_path(user), params: { user: { status: "suspended" } }
    assert_redirected_to admin_users_path
    assert user.reload.suspended?

    patch admin_user_path(user), params: { user: { status: "active" } }
    assert_redirected_to admin_users_path
    assert user.reload.active?
  end

  test "管理者は自分自身を停止できない" do
    patch admin_user_path(@admin), params: { user: { status: "suspended" } }

    assert_redirected_to admin_users_path
    assert_equal "管理者ユーザーの状態は変更できません", flash[:alert]
    assert @admin.reload.active?
  end
end
