require "test_helper"

class LikeTest < ActiveSupport::TestCase
  test "should be valid with valid attributes" do
    like = likes(:one)
    assert like.valid?
  end

  test "should belong to user" do
    like = likes(:one)
    assert_equal users(:one), like.user
    assert_instance_of User, like.user
  end

  test "should belong to article" do
    like = likes(:one)
    assert_equal articles(:published_ja), like.article
    assert_instance_of Article, like.article
  end

  test "should prevent duplicate likes from same user on same article" do
    duplicate = Like.new(
      user: users(:one),
      article: articles(:published_ja)
    )
    assert_not duplicate.valid?
    assert duplicate.errors[:user_id].any?
  end

  test "should allow same user to like different articles" do
    new_like = Like.new(
      user: users(:one),
      article: articles(:rails_article)
    )
    assert new_like.valid?
    assert new_like.save
  end

  test "should allow different users to like same article" do
    like_from_different_user = Like.new(
      user: users(:admin), 
      article: articles(:published_ja)
    )
    assert like_from_different_user.valid?
    assert like_from_different_user.save
  end

  test "should increment article likes_count on creation" do
    article = articles(:rails_article)
    initial_count = article.likes_count || 0
    Like.create!(user: users(:one), article: article)
    article.reload
    assert_equal initial_count + 1, article.likes_count
  end

  test "should decrement article likes_count on deletion" do
    article = articles(:published_ja)
    like = likes(:one)
    initial_count = article.likes_count
    like.destroy!
    article.reload
    assert_equal initial_count - 1, article.likes_count
  end

  test "should have working user association" do
    like = likes(:one)
    assert_not_nil like.user
    assert_equal users(:one), like.user
    assert_instance_of User, like.user
  end

  test "should have working article association" do
    like = likes(:one)
    assert_not_nil like.article
    assert_equal articles(:published_ja), like.article
    assert_instance_of Article, like.article
  end
end
