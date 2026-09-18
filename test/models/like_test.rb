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

  test "should allow anonymous like via visitor_token" do
    like = Like.new(visitor_token: SecureRandom.uuid, article: articles(:rails_article))
    assert like.valid?
    assert like.save
  end

  test "should prevent duplicate anonymous likes from same visitor_token on same article" do
    token = SecureRandom.uuid
    Like.create!(visitor_token: token, article: articles(:rails_article))
    duplicate = Like.new(visitor_token: token, article: articles(:rails_article))
    assert_not duplicate.valid?
    assert duplicate.errors[:visitor_token].any?
  end

  test "should allow same visitor_token to like different articles" do
    token = SecureRandom.uuid
    Like.create!(visitor_token: token, article: articles(:rails_article))
    other = Like.new(visitor_token: token, article: articles(:published_ja))
    assert other.valid?
  end

  test "should be invalid without both user and visitor_token" do
    like = Like.new(article: articles(:rails_article))
    assert_not like.valid?
    assert like.errors[:base].any?
  end

  test "should increment article likes_count for anonymous like" do
    article = articles(:rails_article)
    initial_count = article.likes_count || 0
    Like.create!(visitor_token: SecureRandom.uuid, article: article)
    article.reload
    assert_equal initial_count + 1, article.likes_count
  end
end
