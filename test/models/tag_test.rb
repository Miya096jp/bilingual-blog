require "test_helper"

class TagTest < ActiveSupport::TestCase
  test "should be valid with valid attributes" do
    tag = tags(:ruby)
    assert tag.valid?
  end

  test "should require name" do
    tag = tags(:ruby)
    tag.name = nil
    assert_not tag.valid?
    assert tag.errors[:name].any?
  end

  test "should require unique name per user" do
    duplicate = Tag.new(
      name: tags(:ruby).name,
      user: users(:one)
    )
    assert_not duplicate.valid?
    assert duplicate.errors[:name].any?
  end

  test "should allow same name for different users" do
    tag_for_different_user = Tag.new(
      name: "ruby",
      user: users(:two)
    )
    assert tag_for_different_user.valid?
  end

  test "should normalize name to lowercase on save" do
    tag = Tag.create!(name: "Ruby On Rails", user: users(:one))
    assert_equal "ruby on rails", tag.name
  end

  test "should strip whitespace from name on save" do
    tag = Tag.create!(name: "  Python  ", user: users(:one))
    assert_equal "python", tag.name
  end

  test "should normalize both case and whitespace" do
    tag = Tag.create!(name: "  RUBY on RAILS  ", user: users(:one))
    assert_equal "ruby on rails", tag.name
  end

  test "should belong to user" do
    tag = tags(:ruby)
    assert_equal users(:one), tag.user
    assert_instance_of User, tag.user
  end

  test "should have many articles through article_tags" do
    tag = tags(:programming)
    assert_respond_to tag, :articles
    assert tag.articles.count > 0
    assert tag.articles.all? { |a| a.is_a?(Article) }
  end

  test "should have many article_tags" do
    tag = tags(:programming)
    assert_respond_to tag, :article_tags
    assert tag.article_tags.count > 0
  end

  test "for_user scope should filter by user" do
    user_tags = Tag.for_user(users(:one))
    assert user_tags.all? { |t| t.user_id == users(:one).id }
    assert_includes user_tags, tags(:ruby)
    assert_includes user_tags, tags(:rails)
  end

  test "should destroy dependent article_tags when tag is deleted" do
    tag = tags(:programming)
    article_tag_ids = tag.article_tags.pluck(:id)
    assert article_tag_ids.any?
    tag.destroy!
    article_tag_ids.each do |id|
      assert_not ArticleTag.exists?(id)
    end
  end
end
