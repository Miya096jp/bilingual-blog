class Category < ApplicationRecord
  belongs_to :user
  has_many :articles, dependent: :nullify

  validates :name, presence: true, uniqueness: { scope: :locale }
  validates :locale, inclusion: { in: %w[ja en] }

  scope :for_locale, ->(locale) { where(locale: locale) }
  scope :with_article_count, -> {
    left_joins(:articles)
      # .group("categories.id")
      .group(:id)
      .select("categories.*, COUNT(articles.id) AS articles_count")
  }

  def display_name
    name
  end
end
