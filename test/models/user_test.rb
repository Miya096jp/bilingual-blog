require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "should be valid with valid attributes" do
    user = users(:one)
    assert user.valid?
  end

  test "should require username" do
    user = users(:one)
    user.username = nil
    assert_not user.valid?
    assert user.errors[:username].any?
  end

  test "should require email" do
    user = users(:one)
    user.email = nil
    assert_not user.valid?
    assert user.errors[:email].any?
  end

  test "should require unique username" do
    duplicate_user = User.new(
      username: users(:one).username,
      email: "different@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    assert_not duplicate_user.valid?
    assert duplicate_user.errors[:username].any?
  end

  test "should require unique email" do
    duplicate_user = User.new(
      username: "different",
      email: users(:one).email,
      password: "password123",
      password_confirmation: "password123"
    )
    assert_not duplicate_user.valid?
    assert duplicate_user.errors[:email].any?
  end

  test "should have default user role" do
    user = users(:one)
    assert_equal "user", user.role
  end

  test "should have default active status" do
    user = users(:one)
    assert_equal "active", user.status
  end

  test "should have blog_setting association" do
    user = users(:one)
    assert_not_nil user.blog_setting
    assert_instance_of BlogSetting, user.blog_setting
  end

  test "should suspend user" do
    user = users(:one)
    user.suspend!
    user.reload

    assert user.suspended?
    assert_equal "suspended", user.status
  end

  test "should restore suspended user" do
    user = users(:suspended)
    assert_equal "suspended", user.status
    user.restore!
    user.reload
    assert_equal "active", user.status
    assert_not user.suspended?
  end

  test "unconfirmed user should not be confirmed" do
    user = users(:unconfirmed)
    assert_nil user.confirmed_at
    assert_equal "pending", user.status
  end

  test "admin user should have admin role" do
    admin = users(:admin)
    assert admin.admin?
    assert_equal "admin", admin.role
  end

  test "should invalidate user with invalid website format" do
    user = users(:one)
    user.website = "not-a-url"
    assert_not user.valid?
    assert user.errors[:website].any?
  end

  test "should accept valid website url" do
    user = users(:one)
    user.website = "https://example.com"
    assert user.valid?
    assert user.errors[:website].empty?
  end

  test "should allow blank website" do
    user = users(:one)
    user.website = nil
    assert user.valid?
    assert user.errors[:website].empty?
  end

  test "should have working blog_setting association" do
    user = users(:one)
    assert_not_nil user.blog_setting
    assert_equal blog_settings(:one), user.blog_setting
    assert_instance_of BlogSetting, user.blog_setting
  end

  test "should have working articles association" do
    user = users(:blogger)
    assert_not_nil user.articles
    assert_includes user.articles, articles(:published_ja)
    assert_includes user.articles, articles(:published_en)
    assert user.articles.all? { |a| a.user_id == user.id }
  end

  test "should have working categories association" do
    user = users(:one)
    assert_not_nil user.categories
    assert_includes user.categories, categories(:technology_ja)
    assert_includes user.categories, categories(:technology_en)
    assert user.categories.all? { |c| c.user_id == user.id }
  end

  test "should have working tags association" do
    user = users(:one)
    assert_not_nil user.tags
    assert_includes user.tags, tags(:ruby)
    assert_includes user.tags, tags(:rails)
    assert user.tags.all? { |t| t.user_id == user.id }
  end

  test "should have working likes association" do
    user = users(:one)
    assert_not_nil user.likes
    assert_includes user.likes, likes(:one)
    assert user.likes.all? { |l| l.user_id == user.id }
  end
end
