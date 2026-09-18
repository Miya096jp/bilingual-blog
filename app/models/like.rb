class Like < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :article, counter_cache: true

  validates :user_id, uniqueness: { scope: :article_id }, allow_nil: true
  validates :visitor_token, uniqueness: { scope: :article_id }, allow_nil: true
  validate :user_or_visitor_token_present

  private

  def user_or_visitor_token_present
    return if user_id.present? || visitor_token.present?

    errors.add(:base, "ユーザーまたは訪問者情報のいずれかが必要です")
  end
end
