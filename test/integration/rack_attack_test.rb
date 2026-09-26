require "test_helper"

class RackAttackTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  # 各制限の対象と上限。path と params はテストのインスタンス上で評価し、params には何回目の送信かを渡す。
  # ログインと新規登録は、失敗時の画面がテスト環境では描画できない（OmniAuth の設定が無い）ため、成功する値で送る。
  THROTTLED_ENDPOINTS = {
    "記事の作成" => { limit: 5, sign_in: :blogger, path: -> { dashboard_articles_path } },
    "ログイン" => { limit: 5, path: -> { user_session_path }, params: ->(_) { login_params } },
    "問い合わせ" => { limit: 3, path: -> { contacts_path(locale: "ja") } },
    "コメントの投稿" => {
      limit: 5,
      path: -> { article_comments_path(articles(:published_ja).user.username, articles(:published_ja), locale: "ja") }
    },
    "いいね" => {
      limit: 30,
      path: -> { user_article_likes_path(articles(:published_ja).user.username, articles(:published_ja), locale: "ja") }
    },
    "画像アップロード" => { limit: 30, sign_in: :blogger, path: -> { dashboard_images_path } },
    "新規登録" => { limit: 10, path: -> { user_registration_path }, params: ->(i) { sign_up_params(i) } },
    "パスワード再設定の依頼" => { limit: 5, path: -> { user_password_path } },
    "確認メールの再送" => { limit: 5, path: -> { user_confirmation_path } }
  }.freeze

  # ルーターが同じアクションに届けるパスの書き方
  PATH_VARIANTS = {
    "末尾にスラッシュ" => ->(path) { "#{path}/" },
    "末尾に.json" => ->(path) { "#{path}.json" },
    "連続したスラッシュ" => ->(path) { path.gsub("/", "//") }
  }.freeze

  setup do
    # Rack::Attack は時刻を period で区切って数えるため、送信の途中で区切りをまたぐと回数がリセットされる。
    # 時刻を止めて、テスト中のリクエストがすべて同じ区切りで数えられるようにする。
    freeze_time

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

  test "記事の作成は上限内であれば制限されない" do
    sign_in users(:blogger)

    assert_difference("Article.count", 5) do
      5.times do
        post dashboard_articles_path, params: article_params
        assert_redirected_to dashboard_articles_path
      end
    end
  end

  test "記事の作成が上限を超えると429になり、Articleも作成されない" do
    sign_in users(:blogger)
    5.times { post dashboard_articles_path, params: article_params }

    assert_no_difference("Article.count") do
      post dashboard_articles_path, params: article_params
    end

    assert_response :too_many_requests
  end

  test "ログインは上限内であれば制限されない" do
    5.times do
      post user_session_path, params: login_params
      assert_redirected_to root_path
      delete destroy_user_session_path
    end
  end

  test "ログインが上限を超えると429になり、ログインもできない" do
    5.times do
      post user_session_path, params: login_params
      delete destroy_user_session_path
    end

    post user_session_path, params: login_params

    assert_response :too_many_requests
    get dashboard_articles_path
    assert_redirected_to new_user_session_path
  end

  test "パスの書き方を混ぜて送っても、ログインの回数は合算される" do
    3.times { post user_session_path, params: login_params }
    2.times { post "#{user_session_path}.json", params: login_params }
    post "#{user_session_path}.json", params: login_params

    assert_response :too_many_requests
  end

  THROTTLED_ENDPOINTS.each do |name, endpoint|
    PATH_VARIANTS.each do |variant_name, variant|
      test "#{name}は、パスの#{variant_name}を付けても同じ回数で数えられる" do
        sign_in users(endpoint[:sign_in]) if endpoint[:sign_in]
        path = instance_exec(&endpoint[:path])
        params = ->(i) { instance_exec(i, &endpoint[:params]) if endpoint[:params] }

        endpoint[:limit].times { |i| post variant.call(path), params: params.call(i) }
        post path, params: params.call(endpoint[:limit])

        assert_response :too_many_requests
      end
    end
  end

  private

  def article_params
    { article: { title: "テスト記事", content: "テスト本文", locale: "ja", status: "draft" } }
  end

  def login_params
    { user: { email: users(:one).email, password: "password123" } }
  end


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
