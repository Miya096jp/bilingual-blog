class Article < ApplicationRecord
  belongs_to :user

  validates :title, presence: true
  validates :content, presence: true
  validates :locale, presence: true, inclusion: { in: %w[ja en] }

  enum :status, %i[draft published]

  has_one :translation, class_name: "Article", foreign_key: "original_article_id", dependent: :destroy
  belongs_to :original_article, class_name: "Article", optional: true
  belongs_to :category, optional: true

  has_many :comments, dependent: :destroy

  has_many_attached :images
  has_one_attached :cover_image

  has_many :article_tags, dependent: :destroy
  has_many :tags, through: :article_tags

  before_save :set_published_at
  after_create :assign_pending_tags

  scope :by_locale, ->(locale) { where(locale: locale) }
  scope :by_category, ->(category_id) { where(category_id: category_id) if category_id.present? }
  scope :by_tags, ->(tag_id, user) { joins(:tags).where(tags: { id: tag_id, user: user }) if tag_id.present? }
  scope :for_listing, ->(locale) {
    published
      .where(locale: locale)
      .includes(:category, :tags, :translation)
      .order(published_at: :desc)
  }
  scope :search, ->(keyword) {
    where("title ILIKE ? OR content ILIKE ?", "%#{keyword}%", "%#{keyword}%") if keyword.present?
  }

  def original?
    original_article_id.nil?
  end

  def translated?
    original_article_id.present?
  end

  def has_translation?
    translation.present?
  end

  def content_html
    # processed_content = content.strip.gsub(/^[ \t]+/, "")
    Kramdown::Document.new(content,
      input: "GFM",
      syntax_highlighter: "rouge"
                          ).to_html.html_safe
  end

  def content_preview(length = 100)
    # HTMLタグを除去して指定文字数でトランケート
    ActionController::Base.helpers.strip_tags(content_html).truncate(length)
  end

  def tag_list
    tags.pluck(:name).join(",")
  end

  def tag_list=(tag_string)
    return if tag_string.blank?

    tag_names = tag_string.split(/[,\s]+/).map(&:strip).reject(&:blank?)

    if user.present?
      # 既存記事または保存済み記事の場合
      new_tags = tag_names.map { |name| user.tags.find_or_create_by(name: name.downcase) }
      self.tags = new_tags
    else
      # 新規記事の場合は、一旦タグ名だけ保存
      @pending_tag_names = tag_names
    end
  end

  private
  def set_published_at
    if status == "published" && published_at.blank?
      self.published_at = Time.current
    end
  end

  def assign_pending_tags
    if @pending_tag_names.present?
      new_tags = @pending_tag_names.map { |name| user.tags.find_or_create_by(name: name.downcase) }
      self.tags = new_tags
    end
  end
end
