require "test_helper"

class WelcomeControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  # OAuthの資格情報がない環境ではDeviseがomniauth用のURLヘルパーを定義せず、
  # レイアウトのログインモーダルが描画できないため、このコントローラに限りダミーを定義する
  if Devise.omniauth_configs.empty?
    WelcomeController.helper(Module.new { def omniauth_authorize_path(*) = "#" })
  end

  # 公開側のページで生成したURLには default_url_options により ?locale= が付く
  def path_pattern(path)
    "#{path}?locale=ja"
  end

  test "ルート(/)は /ja にリダイレクトされる" do
    get "/"

    assert_redirected_to "/ja"
  end

  test "ja と en のトップページが表示できる" do
    get "/ja"
    assert_response :success

    get "/en"
    assert_response :success
  end

  test "ボタンの分岐がSlimのソースのまま露出しない" do
    get "/ja"

    assert_response :success
    assert_no_match "if user_signed_in?", response.body
  end

  test "ヒーローの見出しと、特徴01〜03の見出しが表示される" do
    get "/ja"

    assert_response :success
    assert_select "h1", text: /書きたいことを、\s*ふたつの言葉で。/
    assert_select "h2", text: /日本語と英語の記事を、\s*ペアで管理。/
    assert_select "h2", text: /日記を書くように、\s*誰にも気兼ねなく。/
    assert_select "h2", text: /シンプルなエディターで、\s*書くことに集中。/
  end

  test "運営者(role: admin)のユーザーが存在しなくてもトップページが表示できる" do
    users(:admin).destroy!
    assert_not User.admin.exists?

    get "/ja"
    assert_response :success

    get "/en"
    assert_response :success
  end

  test "運営者の公開記事があっても、そのタイトルは表示されない" do
    operator = users(:admin)
    Article.create!(user: operator, title: "運営者の日本語記事", content: "本文", locale: "ja", status: :published, published_at: 1.day.ago)
    Article.create!(user: operator, title: "Operator English post", content: "body", locale: "en", status: :published, published_at: 1.day.ago)

    get "/ja"
    assert_response :success
    assert_no_match "運営者の日本語記事", response.body
    assert_no_match "はじめに読む", response.body

    get "/en"
    assert_response :success
    assert_no_match "Operator English post", response.body
    assert_no_match "Start here", response.body
  end

  test "未ログインでは、新規登録とログインのモーダルを開くボタンがあり、ダッシュボードへのリンクはない" do
    get "/ja"

    assert_response :success
    assert_select "button[data-action='click->auth-modal#showModal'][data-auth-modal-url-param=?]", path_pattern(new_user_registration_path)
    assert_select "button[data-action='click->auth-modal#showModal']:not([data-auth-modal-url-param])"
    assert_select "a[href=?]", path_pattern(dashboard_articles_path), count: 0
  end

  # リンクにすると Turbo がマウスオーバーで frame 外のリクエストとしてプリフェッチし、
  # そのレスポンス(トップページへのリダイレクト)がモーダルの turbo-frame に流用されてしまう
  test "モーダルを開くトリガーは、プリフェッチされるリンクではなくボタンにする" do
    %w[ja en].each do |locale|
      get "/#{locale}"

      assert_response :success
      assert_select "a[data-action*='auth-modal#showModal']", count: 0
    end
  end

  test "ログイン中は、ダッシュボードへのリンクがあり、新規登録とログインへのリンクはない" do
    sign_in users(:one)

    get "/ja"

    assert_response :success
    assert_select "a[href=?]", path_pattern(dashboard_articles_path)
    assert_select "a[href=?]", path_pattern(new_user_registration_path), count: 0
    assert_select "a[href=?]", path_pattern(new_user_session_path), count: 0
  end

  test "フッターに利用規約・プライバシーポリシー・お問い合わせへのリンクがある" do
    get "/ja"

    assert_response :success
    assert_select "footer" do
      assert_select "a[href=?]", terms_of_service_path(locale: "ja"), text: "利用規約"
      assert_select "a[href=?]", privacy_policy_path(locale: "ja"), text: "プライバシーポリシー"
      assert_select "a[href=?]", new_contact_path(locale: "ja"), text: "お問い合わせ"
    end
  end

  test "ログインモーダルの見出しがロケールに関わらず日本語で表示される" do
    get "/ja"
    assert_select "#auth_modal_overlay h3", text: "ログイン"

    get "/en"
    assert_select "#auth_modal_overlay h3", text: "ログイン"
  end

  test "title と description が新しいコンセプトの文言になり、keywords は出力されない" do
    get "/ja"

    assert_response :success
    assert_select "title", text: "Dual Pascal — 日本語と英語で書く、あなただけのブログ"
    assert_select "meta[name=description][content=?]", "日本語と英語で、自分のペースで書ける個人ブログ。コミュニティもタイムラインもない、あなただけのブログです。"
    assert_select "meta[name=keywords]", count: 0

    get "/en"

    assert_response :success
    assert_select "title", text: "Dual Pascal — Your own blog, in Japanese and English"
    assert_select "meta[name=description][content=?]", "A personal blog where you can write in Japanese and English at your own pace. No community, no timeline — just your own blog."
    assert_select "meta[name=keywords]", count: 0
  end
end
