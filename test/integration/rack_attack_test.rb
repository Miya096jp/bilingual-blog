require "test_helper"

class RackAttackTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

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

  test "コメントの投稿は上限内であれば制限されない" do
    article = articles(:published_ja)

    assert_difference("Comment.count", 5) do
      5.times do
        post article_comments_path(article.user.username, article, locale: "ja"), params: comment_params
        assert_response :redirect
      end
    end
  end

  test "コメントの投稿が上限を超えると429になり、Commentも作成されない" do
    article = articles(:published_ja)
    5.times { post article_comments_path(article.user.username, article, locale: "ja"), params: comment_params }

    assert_no_difference("Comment.count") do
      post article_comments_path(article.user.username, article, locale: "ja"), params: comment_params
    end

    assert_response :too_many_requests
  end

  test "いいねは上限内であれば制限されない" do
    article = articles(:published_ja)

    30.times do
      post user_article_likes_path(article.user.username, article, locale: "ja")
      assert_response :redirect
    end
  end

  test "いいねが上限を超えると429になり、Likeも作成されない" do
    article = articles(:published_ja)
    30.times { post user_article_likes_path(article.user.username, article, locale: "ja") }
    cookies.delete(:visitor_token)

    assert_no_difference("Like.count") do
      post user_article_likes_path(article.user.username, article, locale: "ja")
    end

    assert_response :too_many_requests
  end

  test "画像アップロードは上限内であれば制限されない" do
    sign_in users(:blogger)
    29.times { post dashboard_images_path }
    before_count = ActiveStorage::Blob.count

    post dashboard_images_path, params: { image: fixture_file_upload("portrait.png", "image/png") }

    assert_response :success
    assert_operator ActiveStorage::Blob.count, :>, before_count
  end

  test "画像アップロードが上限を超えると429になり、blobも作成されない" do
    sign_in users(:blogger)
    30.times { post dashboard_images_path }

    assert_no_difference("ActiveStorage::Blob.count") do
      post dashboard_images_path, params: { image: fixture_file_upload("portrait.png", "image/png") }
    end

    assert_response :too_many_requests
  end

  test "画像アップロードの上限はユーザーごとに数える" do
    sign_in users(:blogger)
    30.times { post dashboard_images_path }
    sign_out :user

    sign_in users(:one)
    post dashboard_images_path

    assert_response :unprocessable_entity
  end

  private

  def comment_params
    { comment: { author_name: "テスト太郎", content: "テストコメント本文" } }
  end

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
