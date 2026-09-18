require "test_helper"

class RackAttackTest < ActionDispatch::IntegrationTest
  setup do
    @original_store = Rack::Attack.cache.store
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

    @valid_params = {
      contact: {
        name: "テスト太郎",
        email: "test@example.com",
        subject: "テスト件名",
        message: "テストメッセージ"
      }
    }
  end

  teardown do
    Rack::Attack.cache.store = @original_store
  end

  test "問い合わせフォームへの送信は上限内であれば制限されない" do
    3.times do
      post contacts_path(locale: "ja"), params: @valid_params
      assert_response :redirect
    end
  end

  test "問い合わせフォームへの送信が上限を超えると429になり、Contactも作成されない" do
    3.times do
      post contacts_path(locale: "ja"), params: @valid_params
      assert_response :redirect
    end

    assert_no_difference("Contact.count") do
      post contacts_path(locale: "ja"), params: @valid_params
    end

    assert_response :too_many_requests
  end
end
