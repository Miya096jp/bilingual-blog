require "test_helper"

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  # OAuthの資格情報がない環境ではDeviseがomniauth用のURLヘルパーを定義せず、
  # レイアウトのログインモーダルが描画できないため、このコントローラに限りダミーを定義する
  if Devise.omniauth_configs.empty?
    ProfilesController.helper(Module.new { def omniauth_authorize_path(*) = "#" })
  end

  setup do
    @user = users(:blogger)
  end

  test "本文がMarkdownとして描画される" do
    @user.update!(profile_body_ja: "## 経歴\n\n- Ruby\n- Rails\n\n[GitHub](https://github.com/example)")

    get user_profile_path(username: @user.username, locale: "ja")

    assert_response :success
    assert_select "article.article-content h2", text: "経歴"
    assert_select "article.article-content ul li", count: 2
    assert_select "article.article-content a[href=?]", "https://github.com/example"
  end

  test "本文中のscriptはサニタイズされる" do
    @user.update!(profile_body_ja: "本文\n\n<script>alert('xss')</script>")

    get user_profile_path(username: @user.username, locale: "ja")

    assert_response :success
    assert_select "article.article-content script", count: 0
    assert_select "article.article-content", text: /本文/
  end

  test "ポートレートがない場合は画像領域を出さない" do
    @user.update!(profile_body_ja: "本文")

    get user_profile_path(username: @user.username, locale: "ja")

    assert_response :success
    assert_select ".profile-portrait", count: 0
  end

  test "ポートレートがある場合は上部に表示される" do
    @user.portrait.attach(io: File.open(file_fixture("portrait.png")), filename: "portrait.png", content_type: "image/png")

    get user_profile_path(username: @user.username, locale: "ja")

    assert_response :success
    assert_select ".profile-portrait img", count: 1
  end

  test "本文が空でも表示でき、記事一覧へのリンクが出る" do
    get user_profile_path(username: @user.username, locale: "ja")

    assert_response :success
    assert_select "article.article-content", count: 0
    assert_select "h1", text: "テストブロガー"
    assert_select "a[href=?]", user_articles_path(@user.username, locale: "ja")
  end

  test "ja と en の両ロケールで表示でき、表示名と本文が切り替わる" do
    @user.update!(nickname_en: "Test Blogger", profile_body_ja: "日本語の本文", profile_body_en: "English body")

    get user_profile_path(username: @user.username, locale: "ja")
    assert_response :success
    assert_select "h1", text: "テストブロガー"
    assert_select "article.article-content", text: /日本語の本文/
    assert_select "a[href=?]", user_articles_path(@user.username, locale: "ja"), text: "記事一覧へ →"

    get user_profile_path(username: @user.username, locale: "en")
    assert_response :success
    assert_select "h1", text: "Test Blogger"
    assert_select "article.article-content", text: /English body/
    assert_select "a[href=?]", user_articles_path(@user.username, locale: "en"), text: "View articles →"
  end

  test "本文が片方のロケールにしかなくてもフォールバックして表示される" do
    @user.update!(profile_body_ja: "日本語だけの本文")

    get user_profile_path(username: @user.username, locale: "en")

    assert_response :success
    assert_select "article.article-content", text: /日本語だけの本文/
  end

  test "旧プロフィール項目は表示されない" do
    @user.update!(location_ja: "東京", twitter_handle: "oldhandle", github_handle: "oldgithub")

    get user_profile_path(username: @user.username, locale: "ja")

    assert_response :success
    assert_no_match "Ruby と Rails が好きです", response.body
    assert_no_match "oldhandle", response.body
    assert_no_match "oldgithub", response.body
  end
end
