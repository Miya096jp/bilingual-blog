require "test_helper"

class CategoryTest < ActiveSupport::TestCase
  test "should be valid with valid attributes" do
    category = categories(:technology_ja)
    assert category.valid?
  end

  test "should require name" do
    category = categories(:technology_ja)
    category.name = nil
    assert_not category.valid?
    assert category.errors[:name].any?
  end

  test "should require unique name per locale combination" do
    duplicate = Category.new(
      name: categories(:technology_ja).name,
      locale: "ja",
      user: users(:one)
    )
    assert_not duplicate.valid?
    assert duplicate.errors[:name].any?
  end

  test "should allow same name for different locale" do
    ja_category = categories(:technology_ja)
    en_category = categories(:technology_en)
    
    assert ja_category.valid?
    assert en_category.valid?
    assert_not_equal ja_category.locale, en_category.locale
  end

  test "should allow same name for different users" do
    category_for_different_user = Category.new(
      name: categories(:technology_ja).name,
      locale: "ja",
      user: users(:two) # Different user
    )
    
    assert category_for_different_user.valid?
  end

  test "should only accept valid locales" do
    category = categories(:technology_ja)
    
    category.locale = "fr"
    assert_not category.valid?
    assert category.errors[:locale].any?
    
    category.locale = "ja"
    assert category.valid?
    
    category.locale = "en"
    assert category.valid?
  end

  test "should belong to user" do
    category = categories(:technology_ja)
    assert_equal users(:one), category.user
    assert_instance_of User, category.user
  end

  test "should have many articles" do
    category = categories(:programming_ja)
    
    assert_respond_to category, :articles
    assert category.articles.count > 0
    assert category.articles.all? { |a| a.is_a?(Article) }
  end

  test "for_locale scope should filter by locale" do
    ja_categories = Category.for_locale("ja")
    assert ja_categories.all? { |c| c.locale == "ja" }
    assert_includes ja_categories, categories(:technology_ja)
    assert_not_includes ja_categories, categories(:technology_en)
    
    en_categories = Category.for_locale("en")
    assert en_categories.all? { |c| c.locale == "en" }
    assert_includes en_categories, categories(:technology_en)
    assert_not_includes en_categories, categories(:technology_ja)
  end

  test "with_article_count scope should include article count" do
    categories = Category.with_article_count
    category = categories.find { |c| c.id == categories(:programming_ja).id }
    assert_respond_to category, :articles_count
    assert category.articles_count > 0
  end

  test "display_name should return name" do
    category = categories(:technology_ja)
    # display_name is just an alias for name
    assert_equal category.name, category.display_name
  end

  test "should nullify article category_id when category is deleted" do
    category = categories(:programming_ja)
    article = articles(:published_ja)
    assert_equal category, article.category
    category.destroy!
    article.reload
    assert_nil article.category_id
  end
end
