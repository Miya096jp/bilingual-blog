require "application_system_test_case"

class ArticleEditingTest < ApplicationSystemTestCase
  def setup
    @user = users(:one)
    @article = articles(:test_article)
    sign_in_as(@user)
  end

  test "user can edit article title and content" do
    visit dashboard_articles_path
    click_link "編集", match: :first
    fill_in "title", with: "更新されたタイトル"
    fill_in "content", with: "# 更新された内容\n\n新しい本文です。"
    click_button "更新"
    assert_current_path dashboard_articles_path
    assert_text "記事が更新されました"
    @article.reload
    assert_equal "更新されたタイトル", @article.title
    assert_includes @article.content, "更新された内容"
  end

  test "user can change article status from draft to published" do
    assert_equal "draft", @article.status
    assert_nil @article.published_at
    visit edit_dashboard_article_path(@article)
    select "公開", from: "article[status]"
    click_button "更新"
    @article.reload
    assert_equal "published", @article.status
    assert_not_nil @article.published_at
  end

  test "user can add tags to existing article" do
    initial_tag_count = @article.tags.count
    visit edit_dashboard_article_path(@article)
    fill_in "article[tag_list]", with: "新規タグ1, 新規タグ2"
    click_button "更新"
    @article.reload
    assert @article.tags.pluck(:name).include?("新規タグ1")
    assert @article.tags.pluck(:name).include?("新規タグ2")
  end

  test "user can remove category from article" do
    @article.update!(category: categories(:technology_ja))
    visit edit_dashboard_article_path(@article)
    select "---", from: "article[category_id]"
    click_button "更新"
    @article.reload
    assert_nil @article.category
  end

  test "cannot save article without required fields" do
    visit edit_dashboard_article_path(@article)
    fill_in "title", with: ""
    click_button "更新"
    @article.reload
    assert_not_equal "", @article.title
  end

  test "user can delete article" do
    article_id = @article.id
    visit edit_dashboard_article_path(@article)
    accept_confirm do
      click_link "削除"
    end
    assert_current_path dashboard_articles_path
    assert_text "削除しました"
    assert_not Article.exists?(article_id)
  end

  test "cancel button returns to articles list without saving" do
    visit edit_dashboard_article_path(@article)
    original_title = @article.title
    fill_in "title", with: "変更したが保存しない"
    click_link "キャンセル"
    assert_current_path dashboard_articles_path
    @article.reload
    assert_equal original_title, @article.title
  end
end
