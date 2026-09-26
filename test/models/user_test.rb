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

  test "停止中のユーザーは認証の対象外になり、停止中である旨のメッセージキーを返す" do
    user = users(:suspended)

    assert_not user.active_for_authentication?
    assert_equal :suspended, user.inactive_message
  end

  test "停止していないユーザーは認証の対象になる" do
    assert users(:blogger).active_for_authentication?
  end

  test "停止を解除すると認証の対象に戻る" do
    user = users(:suspended)
    user.restore!

    assert user.active_for_authentication?
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

  test "should save and update profile bodies" do
    user = users(:one)
    user.update!(profile_body_ja: "# こんにちは", profile_body_en: "# Hello")
    user.reload
    assert_equal "# こんにちは", user.profile_body_ja
    assert_equal "# Hello", user.profile_body_en

    user.update!(profile_body_ja: "更新後")
    assert_equal "更新後", user.reload.profile_body_ja
  end

  test "localized_profile_body returns the body of the given locale" do
    user = User.new(profile_body_ja: "日本語", profile_body_en: "English")
    assert_equal "日本語", user.localized_profile_body("ja")
    assert_equal "English", user.localized_profile_body("en")
  end

  test "localized_profile_body falls back to en when ja is blank" do
    user = User.new(profile_body_ja: "", profile_body_en: "English")
    assert_equal "English", user.localized_profile_body("ja")
  end

  test "localized_profile_body falls back to ja when en is blank" do
    user = User.new(profile_body_ja: "日本語", profile_body_en: nil)
    assert_equal "日本語", user.localized_profile_body("en")
  end

  test "localized_profile_body is empty when both are blank" do
    user = User.new(profile_body_ja: nil, profile_body_en: "")
    assert_equal "", user.localized_profile_body("ja")
    assert_equal "", user.localized_profile_body("en")
  end

  test "profile_body_html renders markdown" do
    user = User.new(profile_body_ja: "# Hello")
    assert_match %r{<h1>Hello</h1>}, user.profile_body_html("ja")
  end

  test "profile_body_html strips script tags" do
    user = User.new(profile_body_ja: "Hi <script>alert('hack')</script>")
    html = user.profile_body_html("ja")
    assert_no_match(/<script>/, html)
    assert_includes html, "Hi"
    assert html.html_safe?
  end

  test "profile_body_html is empty when both bodies are blank" do
    assert_equal "", User.new.profile_body_html("ja").strip
  end

  test "should attach a portrait" do
    user = users(:one)
    user.portrait.attach(io: StringIO.new("png-data"), filename: "portrait.png", content_type: "image/png")
    assert user.valid?
    assert user.portrait.attached?
  end

  test "should accept jpeg and webp portraits" do
    user = users(:one)
    %w[image/jpeg image/webp].each do |type|
      user.portrait.attach(io: StringIO.new("data"), filename: "portrait", content_type: type)
      assert user.valid?, "#{type} should be valid"
    end
  end

  test "should reject a portrait with an invalid content type" do
    user = users(:one)
    user.portrait.attach(io: StringIO.new("gif-data"), filename: "portrait.gif", content_type: "image/gif")
    assert_not user.valid?
    assert user.errors[:portrait].any?
  end

  test "should reject a portrait of 5MB or more" do
    user = users(:one)
    user.portrait.attach(io: StringIO.new("a" * 5.megabytes), filename: "portrait.png", content_type: "image/png")
    assert_not user.valid?
    assert user.errors[:portrait].any?
  end

  test "should purge avatar and portrait when user is destroyed" do
    user = users(:one)
    user.avatar.attach(io: StringIO.new("png-data"), filename: "avatar.png", content_type: "image/png")
    user.portrait.attach(io: StringIO.new("png-data"), filename: "portrait.png", content_type: "image/png")
    user.save!
    avatar_blob_id = user.avatar.blob.id
    portrait_blob_id = user.portrait.blob.id

    assert_difference "ActiveStorage::Blob.count", -2 do
      user.destroy
    end
    assert_not ActiveStorage::Blob.exists?(avatar_blob_id)
    assert_not ActiveStorage::Blob.exists?(portrait_blob_id)
  end

  test "should destroy user without attachments" do
    user = users(:one)
    assert_not user.avatar.attached?
    assert_not user.portrait.attached?

    assert_nothing_raised { user.destroy }
    assert user.destroyed?
  end
end
