
require "test_helper"

class BlogSettingTest < ActiveSupport::TestCase
  test "should be valid with valid attributes" do
    setting = blog_settings(:one)
    assert setting.valid?
  end

  test "should belong to user" do
    setting = blog_settings(:one)
    assert_equal users(:one), setting.user
    assert_instance_of User, setting.user
  end

  test "should reject invalid theme_color" do
    setting = blog_settings(:one)
    setting.theme_color = "invalid_color"
    assert_not setting.valid?
    assert setting.errors[:theme_color].any?
  end

  test "should accept all valid theme colors" do
    setting = blog_settings(:one)

    BlogSetting::THEME_COLORS.each do |color|
      setting.theme_color = color
      assert setting.valid?, "#{color} should be valid"
      assert setting.errors[:theme_color].empty?
    end
  end

  test "should reject invalid layout_style" do
    setting = blog_settings(:one)
    setting.layout_style = "invalid_layout"
    
    assert_not setting.valid?
    assert setting.errors[:layout_style].any?
  end

  test "should accept all valid layout styles" do
    setting = blog_settings(:one)
    
    # Test all valid layout styles from model enum
    valid_styles = %w[linear hero_tiles hero_list]
    
    valid_styles.each do |style|
      setting.layout_style = style
      assert setting.valid?, "#{style} should be a valid layout style"
      assert setting.errors[:layout_style].empty?
    end
  end

  test "should require unique user_id" do
    # Try to create second blog_setting for same user
    duplicate = BlogSetting.new(
      user: users(:one), # Same user as blog_settings(:one)
      theme_color: "default"
    )
    
    assert_not duplicate.valid?
    assert duplicate.errors[:user_id].any?
  end

  test "display_title should return appropriate localized title" do
    setting = blog_settings(:one)
    
    # Should return Japanese title for ja locale
    ja_title = setting.display_title("ja")
    assert_equal "testuser のブログ", ja_title
    
    # Should return English title for en locale
    en_title = setting.display_title("en")
    assert_equal "testuser's Blog", en_title
  end

  test "display_title should fallback when primary locale is missing" do
    setting = blog_settings(:one)
    
    # Remove Japanese title
    setting.update_column(:blog_title_ja, nil)
    
    # Should fallback to English when Japanese is missing
    ja_title = setting.display_title("ja")
    assert_equal "testuser's Blog", ja_title
  end

  test "display_title should fallback to default when both are missing" do
    setting = blog_settings(:one)
    
    # Remove both titles
    setting.update_columns(blog_title_ja: nil, blog_title_en: nil)
    
    # Should return default "Dual Pascal"
    title = setting.display_title("ja")
    assert_equal "Dual Pascal", title
  end

  test "display_subtitle should return appropriate localized subtitle" do
    setting = blog_settings(:one)
    
    # Test both locales
    ja_subtitle = setting.display_subtitle("ja")
    assert_equal "テストブログです", ja_subtitle
    
    en_subtitle = setting.display_subtitle("en")
    assert_equal "This is a test blog", en_subtitle
  end

  test "display_subtitle should fallback when primary locale is missing" do
    setting = blog_settings(:one)
    
    # Remove Japanese subtitle
    setting.update_column(:blog_subtitle_ja, nil)
    
    # Should fallback to English
    ja_subtitle = setting.display_subtitle("ja")
    assert_equal "This is a test blog", ja_subtitle
  end

  test "display_subtitle should return empty string when both are missing" do
    setting = blog_settings(:one)
    
    # Remove both subtitles
    setting.update_columns(blog_subtitle_ja: nil, blog_subtitle_en: nil)
    
    # Should return empty string
    subtitle = setting.display_subtitle("ja")
    assert_equal "", subtitle
  end

  test "localized_title should respect given locale" do
    setting = blog_settings(:one)
    
    # Should return exactly the locale requested, no fallback
    assert_equal "testuser のブログ", setting.localized_title("ja")
    assert_equal "testuser's Blog", setting.localized_title("en")
  end

  test "localized_subtitle should respect given locale" do
    setting = blog_settings(:one)
    
    assert_equal "テストブログです", setting.localized_subtitle("ja")
    assert_equal "This is a test blog", setting.localized_subtitle("en")
  end

  test "show_hero_thumbnail should default to false" do
    # Create new setting without specifying show_hero_thumbnail
    setting = BlogSetting.create!(
      user: users(:suspended), # Use a user without blog_setting
      theme_color: "default"
    )
    
    # Should default to false
    assert_equal false, setting.show_hero_thumbnail
  end

  test "should have working user association" do
    setting = blog_settings(:one)
    assert_not_nil setting.user
    assert_equal users(:one), setting.user
    assert_instance_of User, setting.user
  end
end
