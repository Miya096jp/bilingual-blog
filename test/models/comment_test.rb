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

  test "websiteにjavascript:で始まる値を入れると無効になる" do
    comment = comments(:one)
    comment.website = "javascript:alert(1)"

    assert_not comment.valid?
    assert comment.errors[:website].any?
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

  test "author_name は50文字までなら有効で、51文字だと無効になる" do
    comment = comments(:one)

    comment.author_name = "a" * 50
    assert comment.valid?

    comment.author_name = "a" * 51
    assert_not comment.valid?
    assert comment.errors[:author_name].any?
  end

  test "content は2000文字までなら有効で、2001文字だと無効になる" do
    comment = comments(:one)

    comment.content = "a" * 2000
    assert comment.valid?

    comment.content = "a" * 2001
    assert_not comment.valid?
    assert comment.errors[:content].any?
  end

  test "website は255文字までなら有効で、256文字だと無効になる" do
    comment = comments(:one)
    prefix = "https://example.com/"

    comment.website = prefix + "a" * (255 - prefix.length)
    assert comment.valid?

    comment.website = prefix + "a" * (256 - prefix.length)
    assert_not comment.valid?
    assert comment.errors[:website].any?
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
