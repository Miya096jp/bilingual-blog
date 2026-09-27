require "test_helper"

class Admin::AccessTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in users(:blogger)
  end

  {
    "トップ" => :admin_root_path,
    "ユーザー" => :admin_users_path,
    "記事" => :admin_articles_path,
    "お問い合わせ" => :admin_contacts_path
  }.each do |label, path_helper|
    test "管理者でないユーザーは、管理画面の#{label}に入れない" do
      get public_send(path_helper)

      assert_redirected_to root_path
    end
  end
end
