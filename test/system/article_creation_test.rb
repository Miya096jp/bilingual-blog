require "application_system_test_case"

class ArticleCreationTest < ApplicationSystemTestCase
  def setup
    @user = users(:one)
    @category = categories(:technology_ja)
    sign_in_as(@user)
  end

  test "user can create a draft article with minimal information" do
    visit dashboard_articles_path
    click_link "新しい記事を作成"
    fill_in "title", with: "新しいテスト記事"
    fill_in "content", with: "これはテスト本文です。"
    assert_equal "ja", find_field("article[locale]").value
    click_button "投稿"
    assert_text "記事が作成されました"
    assert Article.exists?(title: "新しいテスト記事")
    article = Article.find_by(title: "新しいテスト記事")
    assert_equal "draft", article.status
    assert_nil article.published_at
  end

  test "user can create published article and published_at is set" do
    visit dashboard_articles_path
    click_link "新しい記事を作成"
    fill_in "title", with: "公開記事テスト"
    fill_in "content", with: "公開する記事です。"
    select "公開", from: "article[status]"
    click_button "投稿"
    article = Article.find_by(title: "公開記事テスト")
    assert_equal "published", article.status
    assert_not_nil article.published_at
    assert article.published_at <= Time.current
  end

  test "user can create article with category" do
    visit dashboard_articles_path
    click_link "新しい記事を作成"
    fill_in "title", with: "カテゴリ付き記事"
    fill_in "content", with: "カテゴリのテストです。"
    select @category.name, from: "article[category_id]"
    click_button "投稿"
    article = Article.find_by(title: "カテゴリ付き記事")
    assert_equal @category, article.category
  end

  test "user can create article with tags" do
    visit dashboard_articles_path
    click_link "新しい記事を作成"
    fill_in "title", with: "タグ付き記事"
    fill_in "content", with: "タグのテストです。"
    fill_in "article[tag_list]", with: "Ruby, Rails, テスト, プログラミング"
    click_button "投稿"
    article = Article.find_by(title: "タグ付き記事")
    assert_equal 4, article.tags.count
    tag_names = article.tags.pluck(:name)
    assert_includes tag_names, "ruby"
    assert_includes tag_names, "rails"
    assert_includes tag_names, "テスト"
    assert_includes tag_names, "プログラミング"
  end

  test "markdown preview updates in real-time" do
    visit dashboard_articles_path
    click_link "新しい記事を作成"
    fill_in "content", with: "# テスト見出し\n\n本文です。"
    sleep 0.2
    within("[data-markdown-preview-target='preview']") do
      assert_selector "h1", text: "テスト見出し"
      assert_text "本文です。"
    end
  end

  test "title preview updates when typing title" do
    visit dashboard_articles_path
    click_link "新しい記事を作成"
    fill_in "title", with: "プレビュータイトルテスト"
    # Trigger preview update (might need to blur or just wait)
    find_field("title").native.send_keys(:tab)
    sleep 0.1
    within("[data-markdown-preview-target='titlePreview']") do
      assert_text "プレビュータイトルテスト"
    end
  end

  test "cannot create article without title" do
    visit dashboard_articles_path
    click_link "新しい記事を作成"
    fill_in "content", with: "タイトルなしテスト"
    click_button "投稿"
    assert_not Article.exists?(content: "タイトルなしテスト")
  end

  test "cannot create article without content" do
    visit dashboard_articles_path
    click_link "新しい記事を作成"
    fill_in "title", with: "内容なし記事"
    click_button "投稿"
    assert_not Article.exists?(title: "内容なし記事")
  end

  test "user can select English locale" do
    visit dashboard_articles_path
    click_link "新しい記事を作成"
    select "English", from: "article[locale]"
    fill_in "title", with: "English Article"
    fill_in "content", with: "This is an English article."
    click_button "投稿"
    article = Article.find_by(title: "English Article")
    assert_equal "en", article.locale
  end

  test "layout switcher shows different views" do
    visit dashboard_articles_path
    click_link "新しい記事を作成"
    assert_selector "[data-layout-switcher-target='textArea']", visible: true
    assert_selector "[data-layout-switcher-target='preview']", visible: true
    click_button "☰"
    assert_selector "[data-layout-switcher-target='textArea']", visible: true
    assert_no_selector "[data-layout-switcher-target='preview']", visible: true
    click_button "⚇"
    assert_no_selector "[data-layout-switcher-target='textArea']", visible: true
    assert_selector "[data-layout-switcher-target='preview']", visible: true
  end
end
