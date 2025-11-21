class Comment < ApplicationRecord
  validates :author_name, presence: true
  validates :content, presence: true
  validates :website, format: { with: /\A(http|https):\/\/.+\z/ }, allow_blank: true

  belongs_to :article
end
