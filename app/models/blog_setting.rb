class BlogSetting < ApplicationRecord
  belongs_to :user

  validates :theme_color, inclusion: { in: %w[default slate forest maroon midnight] }
  validates :layout_style, inclusion: { in: %w[linear hero_tiles hero_list] }

  validates :user_id, uniqueness: true

  def display_title(locale = I18.locale)
    localized_title(locale).presence || localized_title(locale == "ja" ? "en" : "ja").presence || "Dual Pascal"
  end

  def localized_title(locale = I18n.locale)
    case locale.to_s
    when "ja" then blog_title_ja
    when "en" then blog_title_en
    else blog_title_ja
    end
  end

  def display_subtitle(locale = I18n.locale)
    localized_subtitle(locale).presence || localized_subtitle(locale == "ja" ? "en" : "ja").presence || ""
  end

  def localized_subtitle(locale = I18n.locale)
    case locale.to_s
    when "ja" then blog_subtitle_ja
    when "en" then blog_subtitle_en
    else blog_subtitle_ja
    end
  end
end
