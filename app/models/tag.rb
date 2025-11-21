class Tag < ApplicationRecord
  belongs_to :user
  has_many :article_tags, dependent: :destroy
  has_many :articles, through: :article_tags

  validates :name, presence: true, uniqueness: { scope: :user_id }

  scope :for_user, ->(user) { where(user: user) }

  before_save :normalize_name

  private

  def normalize_name
    self.name = name.strip.downcase
  end
end
