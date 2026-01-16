require "application_system_test_case"

class PublicArticleViewingTest < ApplicationSystemTestCase
  def setup
    @user = users(:blogger)
    @published_article = articles(:published_ja)
    @draft_article = articles(:draft_ja)
  end

  test "visitor can view list of published articles" do
    visit user_articles_path(@user.username, locale: "ja")
    assert_text @published_article.title
    assert_no_text @draft_article.title
  end

  test "visitor can read full published article" do
    visit user_article_path(@user.username, @published_article.id, locale: "ja")
    assert_selector "h1", text: @published_article.title
    assert_selector ".article-content h1", text: "公開記事"
    assert_text "投稿日"
    assert_text "更新日"
  end

  test "visitor can switch to translated article" do
    visit user_article_path(@user.username, @published_article.id, locale: "ja")
    assert_link "English版"
    click_link "English版"
    english_article = articles(:published_en)
    assert_current_path user_article_path(@user.username, english_article.id, locale: "en")
    assert_text english_article.title
  end

  test "visitor can leave comment on article" do
    visit user_article_path(@user.username, @published_article.id, locale: "ja")
    fill_in "コメント者名", with: "新しいコメンター"
    fill_in "ウェブサイト", with: "https://example.com"
    fill_in "コメント内容", with: "素晴らしい記事をありがとうございます！"
    click_button "コメントを投稿"
    assert_text "新しいコメンター"
    assert_text "素晴らしい記事をありがとうございます！"
    assert @published_article.comments.exists?(author_name: "新しいコメンター")
  end

  test "visitor cannot comment without required fields" do
    visit user_article_path(@user.username, @published_article.id, locale: "ja")
    initial_count = @published_article.comments.count
    click_button "コメントを投稿"
    assert_equal initial_count, @published_article.comments.count
  end

  test "visitor can filter articles by category" do
    category = categories(:programming_ja)
    visit user_articles_path(@user.username, locale: "ja")
    click_link category.name, match: :first
    assert_match /category_id=#{category.id}/, current_url
  end

  test "visitor can search for articles" do
    visit user_articles_path(@user.username, locale: "ja")
    fill_in "q", with: "Rails"
    click_button "検索"
    assert_current_path user_search_path(@user.username, locale: "ja")
    assert_match /q=Rails/, current_url
    assert_text "Rails"
  end

  test "visitor can click tags to filter articles" do
    tag = tags(:programming)
    visit user_article_path(@user.username, @published_article.id, locale: "ja")
    if page.has_link?(tag.name)
      click_link tag.name
      assert_match /tag_id=#{tag.id}/, current_url
    end
  end

  test "visitor sees user profile information" do
    visit user_profile_path(@user.username, locale: "ja")
    assert_text @user.display_name("ja")
    if @user.bio_ja.present?
      assert_text @user.bio_ja
    end
  end

  test "visitor cannot access draft article directly" do
    visit user_article_path(@user.username, @draft_article.id, locale: "ja")
    assert_no_text @draft_article.title
  end

  test "language switcher shows correct locale articles" do
    visit user_articles_path(@user.username, locale: "ja")
    click_link "English"
    assert_match /\/en\//, current_url
  end
end
