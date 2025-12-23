class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :omniauthable, omniauth_providers: [ :github, :google_oauth2 ]


  validates :username, presence: true, uniqueness: true
  validates :website, format: { with: /\A(http|https):\/\/.+\z/ }, allow_blank: true

  enum :role, { user: 0, admin: 1 }
  enum :status, { active: 0, suspended: 1, pending: 2 }

  has_many :articles, dependent: :destroy
  has_many :categories, dependent: :destroy
  has_many :tags, dependent: :destroy
  has_one :blog_setting, dependent: :destroy

  has_one_attached :avatar

  after_create :setup_analytics_async

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

  def suspended?
    status == "suspended"
  end

  def suspend!
    update(status: :suspended)
  end

  def restore!
    update(status: :active)
  end

  def self.from_omniauth(auth)
    user = where(email: auth.info.email).first

    if user
      { user: user, is_new: false }
    else
      new_user = create!(
        email: auth.info.email,
        password: Devise.friendly_token[0, 20],
        username: auth.info.nickname || auth.info.name&.parameterize || auth.info.email.split("@").first
      )
      { user: new_user, is_new: true }
    end
  end

  def analytics_dashboard_url
    umami_share_url
  end

  def has_analytics?
    analytics_setup_completed?
  end

  private

  def setup_analytics_async
    UmamiSetupJob.perform_later(self)
  end
end
