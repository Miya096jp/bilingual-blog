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

  test "新規登録は上限内であれば制限されない" do
    assert_difference("User.count", 10) do
      10.times { |i| post user_registration_path, params: sign_up_params(i) }
    end

    assert_response :redirect
  end

  test "新規登録が上限を超えると429になり、Userも作成されない" do
    10.times { |i| post user_registration_path, params: sign_up_params(i) }

    assert_no_difference("User.count") do
      post user_registration_path, params: sign_up_params(10)
    end

    assert_response :too_many_requests
  end

  test "パスワード再設定の依頼は上限内であれば制限されない" do
    assert_emails 5 do
      5.times do
        post user_password_path, params: { user: { email: users(:one).email } }
        assert_response :redirect
      end
    end
  end

  test "パスワード再設定の依頼が上限を超えると429になり、メールも送信されない" do
    5.times { post user_password_path, params: { user: { email: users(:one).email } } }

    assert_no_emails do
      post user_password_path, params: { user: { email: users(:one).email } }
    end

    assert_response :too_many_requests
  end

  test "確認メールの再送は上限内であれば制限されない" do
    user = users(:unconfirmed)

    assert_emails 5 do
      5.times do
        post user_confirmation_path, params: { user: { email: user.email } }
        assert_response :redirect
      end
    end
  end

  test "確認メールの再送が上限を超えると429になり、メールも送信されない" do
    user = users(:unconfirmed)
    5.times { post user_confirmation_path, params: { user: { email: user.email } } }

    assert_no_emails do
      post user_confirmation_path, params: { user: { email: user.email } }
    end

    assert_response :too_many_requests
  end

  private

  def sign_up_params(index)
    {
      user: {
        username: "newuser#{index}",
        email: "newuser#{index}@example.com",
        password: "password123",
        password_confirmation: "password123"
      }
    }
  end
end
