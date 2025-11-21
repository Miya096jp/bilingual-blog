class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  validates :username, presence: true, uniqueness: true
  validates :website, format: { with: /\A(http|https):\/\/.+\z/ }, allow_blank: true

  enum :role, { user: 0, admin: 1 }

  has_many :articles, dependent: :destroy
  has_many :categories, dependent: :destroy
  has_many :tags, dependent: :destroy
  has_one :blog_setting, dependent: :destroy

  has_one_attached :avatar

  def display_name(locale = I18n.locale)
    localized_nickname(locale).presence || localized_nickname(locale == "ja" ? "en" : "ja").presence || username
  end

  def localized_nickname(locale = I18n.locale)
    case locale.to_s
    when "ja" then nickname_ja
    when "en" then nickname_en
    else nickname_ja
    end
  end

  def localized_bio(locale = I18n.locale)
    case locale.to_s
    when "ja" then bio_ja
    when "en" then bio_en
    else bio_ja
    end
  end

  def localized_location(locale = I18n.locale)
    case locale.to_s
    when "ja" then location_ja
    when "en" then location_en
    else location_ja
    end
  end

  def avatar_url
    avatar.attached? ? avatar : nil
  end

  def blog_setting
    super || create_blog_setting
  end
end
