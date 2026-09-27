class Comment < ApplicationRecord
  validates :author_name, presence: true, length: { maximum: 50 }
  validates :content, presence: true, length: { maximum: 2000 }
  validates :website, format: { with: /\A(http|https):\/\/.+\z/ }, length: { maximum: 255 }, allow_blank: true

  belongs_to :article
end
