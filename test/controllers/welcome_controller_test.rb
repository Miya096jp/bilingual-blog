require "test_helper"

class WelcomeControllerTest < ActionDispatch::IntegrationTest
  # OAuthの資格情報がない環境ではDeviseがomniauth用のURLヘルパーを定義せず、
  # レイアウトのログインモーダルが描画できないため、このコントローラに限りダミーを定義する
  if Devise.omniauth_configs.empty?
    WelcomeController.helper(Module.new { def omniauth_authorize_path(*) = "#" })
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

  test "ヒーローのボタン行がSlimのソースのまま露出しない" do
    get "/ja"

    assert_response :success
    assert_no_match "if user_signed_in?", response.body
    assert_select "div.flex.flex-col.items-center.justify-center", count: 1
  end

  test "運営者(role: admin)の公開済み記事が新しい順に3本まで表示される" do
    operator = users(:admin)
    Article.create!(user: operator, title: "4本目", content: "本文", locale: "ja", status: :published, published_at: 4.days.ago)
    Article.create!(user: operator, title: "古い記事", content: "本文", locale: "ja", status: :published, published_at: 3.days.ago)
    Article.create!(user: operator, title: "中間記事", content: "本文", locale: "ja", status: :published, published_at: 2.days.ago)
    Article.create!(user: operator, title: "最新記事", content: "本文", locale: "ja", status: :published, published_at: 1.day.ago)
    Article.create!(user: operator, title: "下書き", content: "本文", locale: "ja", status: :draft)
    Article.create!(user: operator, title: "English post", content: "body", locale: "en", status: :published, published_at: 1.hour.ago)

    get "/ja"

    assert_response :success
    assert_select "li", count: 3
    titles = css_select("li a span.font-medium").map(&:text)
    assert_equal [ "最新記事", "中間記事", "古い記事" ], titles
  end

  test "運営者に対象ロケールの公開記事が無い場合、「はじめに読む」節は表示されない" do
    get "/ja"

    assert_response :success
    assert_no_match "はじめに読む", response.body
  end

  test "運営者のユーザー名を変更してもトップページは壊れない" do
    operator = users(:admin)
    Article.create!(user: operator, title: "ユーザー名変更後の記事", content: "本文", locale: "ja", status: :published, published_at: 1.day.ago)
    operator.update!(username: "renamed_admin")

    get "/ja"

    assert_response :success
    assert_equal [ "ユーザー名変更後の記事" ], css_select("li a span.font-medium").map(&:text)
  end
end
