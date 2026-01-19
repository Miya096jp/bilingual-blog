require "test_helper"


class CommentTest < ActiveSupport::TestCase
  test "should be valid with valid attributes" do
    comment = comments(:one)
    assert comment.valid?
  end

  test "should require author_name" do
    comment = comments(:one)
    comment.author_name = nil
    assert_not comment.valid?
    assert comment.errors[:author_name].any?
  end

  test "should require content" do
    comment = comments(:one)
    comment.content = nil
    assert_not comment.valid?
    assert comment.errors[:content].any?
  end

  test "should reject invalid website url format" do
    comment = comments(:one)
    invalid_urls = [ "not-a-url", "ftp://example.com", "example.com", "www.example.com" ]

    invalid_urls.each do |invalid_url|
      comment.website = invalid_url
      assert_not comment.valid?, "#{invalid_url} should be invalid"
      assert comment.errors[:website].any?
    end
  end

  test "should accept valid website url formats" do
    comment = comments(:one)

    valid_urls = [ "https://example.com", "http://example.com", "https://sub.example.com/path" ]

    valid_urls.each do |valid_url|
      comment.website = valid_url
      assert comment.valid?, "#{valid_url} should be valid"
      assert comment.errors[:website].empty?
    end
  end

  test "should allow blank website" do
    comment = comments(:two)
    assert_nil comment.website
    assert comment.valid?
  end

  test "should belong to article" do
    comment = comments(:one)
    assert_equal articles(:published_ja), comment.article
    assert_instance_of Article, comment.article
  end


  test "should be ordered by created_at by default" do
    article = articles(:published_ja)
    comments = article.comments
    timestamps = comments.pluck(:created_at)
    assert_equal timestamps.sort.reverse, timestamps
  end
end
