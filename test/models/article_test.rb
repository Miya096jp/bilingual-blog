require "test_helper"

class ArticleTest < ActiveSupport::TestCase
  test "should be valid with valid attributes" do
    article = articles(:published_ja)
    assert article.valid?
  end

  test "should require title" do
    article = articles(:test_article)
    article.title = nil
    assert_not article.valid?
    assert article.errors[:title].any?
  end

  test "should require content" do
    article = articles(:test_article)
    article.content = nil
    assert_not article.valid?
    assert article.errors[:content].any?
  end

  test "should require locale" do
    article = articles(:test_article)
    article.locale = nil
    assert_not article.valid?
    assert article.errors[:locale].any?
  end

  test "should only accept valid locales" do
    article = articles(:test_article)
    article.locale = "fr"
    assert_not article.valid?
    assert article.errors[:locale].any?
    
    article.locale = "ja"
    assert article.valid?
    
    article.locale = "en"
    assert article.valid?
  end

  test "should have default draft status" do
    article = Article.new(
      title: "New Article",
      content: "Content",
      locale: "ja",
      user: users(:one)
    )
    article.save!
    
    assert_equal "draft", article.status
  end

  test "should set published_at when status changes to published" do
    article = articles(:draft_ja)
    assert_nil article.published_at
    article.update!(status: :published)
    
    assert_not_nil article.published_at
    assert article.published_at >= 1.minute.ago
    assert article.published_at <= Time.current
  end

  test "should not override existing published_at when republishing" do
    article = articles(:published_ja)
    original_published_at = article.published_at
    article.update!(status: :draft)
    article.update!(status: :published)
    assert_equal original_published_at.to_i, article.published_at.to_i
  end

  test "original? should return true for articles without original_article id" do
    article = articles(:published_ja)
    assert article.original?
    assert_not article.translated?
  end

  test "translated? should return true for articles with original_article" do
    translation = articles(:published_en)
    assert translation.translated?
    assert_not translation.original?
  end

  test "has_translation? should return true when translation exists" do
    original = articles(:published_ja)
    assert original.has_translation?
    assert_not_nil original.translation
  end

  test "has_translation? should return false when no translation" do
    article = articles(:draft_ja)
    assert_not article.has_translation?
    assert_nil article.translation
  end

  test "should convert markdown content to html" do
    article = Article.new(content: "# Hello World") 
   
    assert_match %r{<h1>Hello World</h1>}, article.content_html
  end

  test "should strip javascript from markdown" do
    bad_markdown = "Hello <script>alert('hack')</script>"
    article = Article.new(content: bad_markdown)
    
    html = article.content_html

    assert_no_match /<script>/, html
    assert_includes html, "Hello"
  end

  test "content_html should be html_safe" do
    article = articles(:published_ja)
    html = article.content_html
    assert html.html_safe?
  end

  test "should have working user association" do
    article = articles(:published_ja)
    assert_not_nil article.user
    assert_equal users(:blogger), article.user
    assert_instance_of User, article.user
  end

  test "should have working category association" do
    article = articles(:published_ja)
    assert_not_nil article.category
    assert_equal categories(:programming_ja), article.category
    assert_instance_of Category, article.category
  end

  test "should have working optional category association" do
    article = articles(:test_article)
    article.category = nil
    article.save!
    assert_nil article.category
    assert article.valid?
  end

  test "should have working comments association" do
    article = articles(:published_ja)
    assert_not_nil article.comments
    assert_includes article.comments, comments(:one)
    assert_includes article.comments, comments(:two)
    assert_equal 2, article.comments.count
    assert article.comments.all? { |c| c.article_id == article.id }
  end

  test "should have working tags association through article_tags" do
    article = articles(:published_ja)
    assert_not_nil article.tags
    assert_includes article.tags, tags(:programming)
    assert_includes article.tags, tags(:web)
    assert_equal 2, article.tags.count
  end

  test "should have working likes association" do
    article = articles(:published_ja)
    assert_not_nil article.likes
    assert_includes article.likes, likes(:one)
    assert_includes article.likes, likes(:two)
    assert article.likes.all? { |l| l.article_id == article.id }
  end

  test "should have working translation association" do
    original = articles(:published_ja)
    assert_not_nil original.translation
    assert_equal articles(:published_en), original.translation
  end

  test "should have working original_article association" do
    translation = articles(:published_en)
    assert_not_nil translation.original_article
    assert_equal articles(:published_ja), translation.original_article
  end

  test "published scope should only return published articles" do
    published_articles = Article.published
    assert_includes published_articles, articles(:published_ja)
    assert_includes published_articles, articles(:published_en)
    assert_includes published_articles, articles(:rails_article)
    assert_not_includes published_articles, articles(:draft_ja)
    assert_not_includes published_articles, articles(:test_article)
  end

  test "by_locale scope should filter by locale correctly" do
    ja_articles = Article.by_locale("ja")
    assert ja_articles.all? { |a| a.locale == "ja" }
    assert_includes ja_articles, articles(:published_ja)
    assert_not_includes ja_articles, articles(:published_en)
    
    en_articles = Article.by_locale("en")
    assert en_articles.all? { |a| a.locale == "en" }
    assert_includes en_articles, articles(:published_en)
    assert_not_includes en_articles, articles(:published_ja)
  end

  test "by_category scope should filter by category" do
    category = categories(:programming_ja)
    filtered = Article.by_category(category.id)
    
    assert filtered.all? { |a| a.category_id == category.id }
    assert_includes filtered, articles(:published_ja)
  end

  test "by_category scope should return all when category_id is nil" do
    all_articles = Article.by_category(nil)
    assert_includes all_articles, articles(:published_ja)
    assert_includes all_articles, articles(:test_article)
  end

  test "search scope should find articles by title" do
    results = Article.search("Rails")
    assert_includes results, articles(:rails_article)
  end

  test "search scope should find articles by content" do
    results = Article.search("公開されている")
    assert_includes results, articles(:published_ja)
  end

  test "search scope should return all when keyword is blank" do
    results = Article.search("")
    assert_equal Article.count, results.count
  end

test "for_listing scope should avoid N+1 queries" do
    # 1. Setup Data manually (Fixes the 'undefined method create_list' error)
    # We create 3 articles to prove the loop doesn't trigger extra queries
    3.times do |i|
      article = Article.create!(
        title: "Test Article #{i}", 
        content: "Content", 
        locale: "ja", 
        status: "published",
        published_at: Time.current,
        user: users(:blogger),         
        category: categories(:programming_ja)
      )
    end

    expected_queries = 5 

    assert_queries_count(expected_queries) do
      articles = Article.for_listing("ja")
      
      articles.each do |article|
        article.category&.name
        article.tags.to_a
      end
    end
  end

  test "tag_list= should create tags from comma-separated string" do
    article = articles(:test_article)
    article.tag_list = "ruby, rails, testing"
    article.save!
    assert_equal 3, article.tags.count
    assert article.tags.pluck(:name).include?("ruby")
    assert article.tags.pluck(:name).include?("rails")
    assert article.tags.pluck(:name).include?("testing")
  end

  test "tag_list= should normalize tag names" do
    article = articles(:test_article)
    article.tag_list = "  Ruby , RAILS,  testing  "
    article.save!
    assert article.tags.pluck(:name).all? { |name| name == name.downcase.strip }
  end

  test "liked_by? should return true when user liked the article" do
    article = articles(:published_ja)
    user = users(:one)
    assert article.liked_by?(user)
  end

  test "liked_by? should return false when user has not liked" do
    article = articles(:rails_article)
    user = users(:one)
    assert_not article.liked_by?(user)
  end

  test "liked_by? should return false when user is nil" do
    article = articles(:published_ja)
    assert_not article.liked_by?(nil)
  end

  test "should destroy dependent comments when article is deleted" do
    article = articles(:published_ja)
    comment_ids = article.comments.pluck(:id)
    assert comment_ids.any?
    article.destroy!
    comment_ids.each do |id|
      assert_not Comment.exists?(id)
    end
  end

  test "should destroy dependent tags associations when article is deleted" do
    article = articles(:published_ja)
    article_tag_ids = article.article_tags.pluck(:id)
    assert article_tag_ids.any?
    article.destroy!
    article_tag_ids.each do |id|
      assert_not ArticleTag.exists?(id)
    end
  end
end
