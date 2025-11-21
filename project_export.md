# Project Code Export (MVC + Routes + Schema)
Exported at: 2025-12-10 09:15:31 +0900

---

## File: `app/models/application_record.rb`

```
class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class
end
```

## File: `app/models/article.rb`

```
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

  has_many :article_tags, dependent: :destroy
  has_many :tags, through: :article_tags

  before_save :set_published_at

  scope :by_locale, ->(locale) { where(locale: locale) }
  scope :by_category, ->(category_id) { where(category_id: category_id) if category_id.present? }
  scope :by_tags, ->(tag_id) { joins(:tags).where(tags: { id: tag_id }) if tag_id.present? }
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
    tag_names = tag_string.split(/[,\s]+/).map(&:strip).reject(&:blank?)
    new_tags = tag_names.map { |name| Tag.find_or_create_by(name: name.downcase) }
    self.tags = new_tags
  end

  private
  def set_published_at
    if status == "published" && published_at.blank?
      self.published_at = Time.current
    end
  end
end
```

## File: `app/models/article_tag.rb`

```
class ArticleTag < ApplicationRecord
  belongs_to :article
  belongs_to :tag
end
```

## File: `app/models/blog_setting.rb`

```
class BlogSetting < ApplicationRecord
  belongs_to :user

  has_one_attached :header_image

  validates :theme_color, inclusion: { in: %w[blue green purple gray] }

  validates :user_id, uniqueness: true

  def display_title
    blog_title.presence || "My Blog"
  end

  def display_subtitle
    blog_subtitle.presence || ""
  end
end
```

## File: `app/models/category.rb`

```
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
```

## File: `app/models/comment.rb`

```
class Comment < ApplicationRecord
  validates :author_name, presence: true
  validates :content, presence: true
  validates :website, format: { with: /\A(http|https):\/\/.+\z/ }, allow_blank: true

  belongs_to :article
end
```

## File: `app/models/tag.rb`

```
class Tag < ApplicationRecord
  has_many :article_tags, dependent: :destroy
  has_many :articles, through: :article_tags

  validates :name, presence: true, uniqueness: true

  before_save :normalize_name

  private

  def normalize_name
    self.name = name.strip.downcase
  end
end
```

## File: `app/models/user.rb`

```
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
```

## File: `app/controllers/application_controller.rb`

```
class ApplicationController < ActionController::Base
  include Authorization
  before_action :set_locale
  before_action :set_blog_setting

  protect_from_forgery with: :exception

  def set_locale
    I18n.locale = params[:locale] || I18n.default_locale
  end

  def default_url_options
    # より安全な書き方
    locale = params[:locale] || I18n.locale || "ja"
    { locale: locale }
  end

  def set_blog_setting
    if params[:username].present?
      user = User.find_by(username: params[:username])
      @blog_setting = user&.blog_setting
    end
  end
end
```

## File: `app/controllers/articles_controller.rb`

```
class ArticlesController < ApplicationController
  before_action :set_locale
  def index
    @filter = ArticleFilterQuery.new(params.merge(user: current_user))
    @articles = @filter.call.page(params[:page]).per(10)

    if params[:from_translation_missing]
      flash[:notice] = params[:locale] == "ja" ? "翻訳記事はありません" : "No translation available"
      redirect_to user_articles_path(locale: params[:locale]) and return
    end
  end

  def show
    @article = Article.find(params[:id])
    @comment = Comment.new
  end

  private

  def set_locale
    I18n.locale = params[:locale] || I18n.default_locale
  end
end
```

## File: `app/controllers/comments_controller.rb`

```
class CommentsController < ApplicationController
  def create
    @article = Article.find(params[:article_id])
    @comment = Comment.new(comment_params)
    @comment.article = @article

    if @comment.save
      redirect_to user_article_path(article.user.username, article.id, locale: params[:locale]), notice: "コメントを投稿しました"
    else
      render "articles/show"
    end
  end

  private

  def comment_params
    params.require(:comment).permit(:author_name, :website, :content)
  end
end
```

## File: `app/controllers/concerns/authorization.rb`

```
module Authorization
  extend ActiveSupport::Concern

  private

  def require_admin
    redirect_to root_path, alert: "アクセス権限がありません" unless current_user&.admin?
  end
end
```

## File: `app/controllers/dashboard/articles_controller.rb`

```
class Dashboard::ArticlesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_article, only: %w[show edit update destroy]
  before_action :set_categories, only: %w[new edit create update]
  layout "dashboard"

  def index
    # 元記事とその翻訳をペアでグループ化
    @original_articles = current_user.articles.where(original_article_id: nil)
                                .includes(:translation, :category, :tags)
                                .order(status: :desc, published_at: :desc, created_at: :desc)
                                .page(params[:page]).per(20)
  end

  def show
  end

  def new
    @article = current_user.articles.build
    @article.locale = "ja"
  end

  def create
    @article = current_user.articles.build(article_params)

    if @article.save
      redirect_to dashboard_articles_path(locale: params[:locale]), notice: "記事が作成されました"
    else
      render :new
    end
  end

  def edit
  end

  def update
    if @article.update(article_params)
      redirect_to dashboard_articles_path(locale: params[:locale]), notice: "記事が更新されました"
    else
      render :edit
    end
  end

  def destroy
    if @article.destroy
      redirect_to dashboard_articles_path(locale: params[:locale], notice: "削除しました")
    else
      redirect_to edit_dashboard_article_path(@article, locale: params[:locale]), alert: "削除に失敗しました"
    end
  end

  private

  def set_article
    @article = current_user.articles.find(params[:id])
  end

  def set_categories
    locale = @article&.locale || params[:locale] || "ja"
    @categories = current_user.categories.for_locale(locale).order(:name)
  end

  def article_params
    params.require(:article).permit(:title, :content, :locale, :status, :category_id, :tag_list)
  end
end
```

## File: `app/controllers/dashboard/blog_settings_controller.rb`

```
class Dashboard::BlogSettingsController < ApplicationController
  before_action :authenticate_user!
  layout "dashboard"

  def edit
    @blog_setting = current_user.blog_setting
  end

  def update
    @blog_setting = current_user.blog_setting

    if @blog_setting.update(blog_setting_params)
      redirect_to edit_dashboard_blog_setting_path, notice: "ブログ設定を更新しました"
    else
      render :edit
    end
  end

  private

  def blog_setting_params
    params.require(:blog_setting).permit(:blog_title, :blog_subtitle, :theme_color, :header_image)
  end
end
```

## File: `app/controllers/dashboard/categories_controller.rb`

```
class Dashboard::CategoriesController < ApplicationController
  before_action :set_category, only: %w[show edit update destroy]
  before_action :authenticate_user!
  layout "dashboard"

  def index
    @ja_categories = current_user.categories.for_locale("ja").with_article_count.order(:name)
    @en_categories = current_user.categories.for_locale("en").with_article_count.order(:name)
  end

  def show
  end

  def new
    @category = current_user.categories.build
    @category.locale = params[:locale] || "ja"
  end

  def create
    @category = current_user.categories.build(category_params)
    @category.locale = params[:locale]

    if @category.save
      redirect_to dashboard_categories_path(locale: params[:locale]), notice: "カテゴリが作成されました"
    else
      render :new
    end
  end

  def edit
  end

  def update
    if @category.update(category_params)
      redirect_to dashboard_categories_path(locale: params[:locale]), notice: "カテゴリが更新されました"
    else
      render :edit
    end
  end

  def destroy
    @category.destroy
    redirect_to dashboard_categories_path(locale: params[:locale]), notice: "カテゴリが削除されました"
  end

  private

  def set_category
    @category = current_user.categories.find(params[:id])
  end

  def category_params
    params.require(:category).permit(:name, :description, :locale)
  end
end
```

## File: `app/controllers/dashboard/comments_controller.rb`

```
class Dashboard::CommentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_comment, only: %w[show destroy]
  layout "dashboard"

  def index
    @comments = Comment.includes(:article)
                       .order(created_at: :desc)
                       .page(params[:page]).per(20)
  end

  def show
  end

  def destroy
    if @comment.destroy
      redirect_to dashboard_comments_path(locale: params[:locale], notice: "コメントを削除しました")
    else
      redirect_to dashboard_comments_path(locale: params[:locale], alert: "削除に失敗しました")
    end
  end

  private

  def set_comment
    @comment = Comment.find(params[:id])
  end
end
```

## File: `app/controllers/dashboard/images_controller.rb`

```
class Dashboard::ImagesController < ApplicationController
  before_action :authenticate_user!
  layout "dashboard"

  def create
    # 直接Active Storage::Blobとして保存
    blob = ActiveStorage::Blob.create_and_upload!(
      io: params[:image],
      filename: params[:image].original_filename,
      content_type: params[:image].content_type
    )

    variant = blob.variant(resize_to_limit: [ 800, 600 ]).processed
    image_url = url_for(variant)
    # image_url = url_for(blob)
    render json: { url: image_url }
  rescue => e
    render json: { error: "画像のアップロードに失敗しました: #{e.message}" }, status: 422
  end
end
```

## File: `app/controllers/dashboard/previews_controller.rb`

```
class Dashboard::PreviewsController < ApplicationController
  before_action :authenticate_user!
  layout "dashboard"

  def create
    content = params[:content]

    # content = content.strip.gsub(/^[ \t]+/, "")

    html = Kramdown::Document.new(content,
      input: "GFM",
      syntax_highlighter: "rouge"
    ).to_html

    render json: { html: html }
  rescue => e
    Rails.logger.error "Preview error: #{e.message}"
    render json: { error: "プレビュー生成でエラーが発生しました: #{e.message}" }, status: 422
  end
end
```

## File: `app/controllers/dashboard/profiles_controller.rb`

```
class Dashboard::ProfilesController < ApplicationController
  before_action :authenticate_user!
  layout "dashboard"

  def show
    @user = current_user
  end

  def edit
    @user = current_user
  end

  def update
    @user = current_user
    if @user.update(profile_params)
      redirect_to edit_dashboard_profile_path, notice: "プロフィールを更新しました"
    else
      render :edit
    end
  end

  private

  def profile_params
    params.require(:user).permit(:nickname_ja, :nickname_en, :bio_ja, :bio_en, :website, :location_ja, :location_en, :twitter_handle, :facebook_handle, :linkedin_handle, :avatar)
  end
end
```

## File: `app/controllers/dashboard/translations_controller.rb`

```
class Dashboard::TranslationsController < ApplicationController
  before_action :set_original_article
  before_action :set_translation, only: %w[show edit update destroy]
  before_action :set_categories, only: %w[new edit create update]
  before_action :authenticate_user!
  layout "dashboard"

  def show
  end

  def new
    @translation = @original_article.build_translation
    @translation.title = @original_article.title
    @translation.content = @original_article.content
    @translation.locale = @original_article.locale == "ja" ? "en" : "ja"
    @translation.category_id = nil
    @translation.tag_list = @original_article.tag_list
    @translation.user = current_user
  end

  def create
    @translation = @original_article.build_translation(translation_params)
    @translation.locale = @original_article.locale == "ja" ? "en" : "ja"
    @translation.user = current_user

    if @translation.save
      redirect_to dashboard_articles_path(locale: params[:locale]), notice: "翻訳記事が作成されました"
    else
      render :new
    end
  end

  def edit
  end

  def update
    if @translation.update(translation_params)
      redirect_to dashboard_articles_path(locale: params[:locale]), notice: "翻訳記事が更新されました"
    else
　　　render :edit
    end
  end

  def destroy
    if @translation.destroy
      redirect_to dashboard_articles_path(locale: params[:locale]), notice: "翻訳記事を削除しました"
    else
      redirect_to edit_dashboard_article_translation_path(@original_article, locale: params[:locale]), alert: "削除に失敗しました"
    end
  end

  private

  def set_original_article
    # @original_article = Article.find(params[:article_id])
    @original_article = current_user.articles.find(params[:article_id])
  end

  def set_translation
    @translation = @original_article.translation
  end

  def set_categories
    translation_locale = @translation&.locale || (@original_article.locale == "ja" ? "en" : "ja")
    @categories = current_user.categories.for_locale(translation_locale).order(:name)
  end

  def translation_params
    params.require(:article).permit(:title, :content, :status, :category_id)
  end
end
```

## File: `app/controllers/profiles_controller.rb`

```
class ProfilesController < ApplicationController
  def show
    @user = User.find_by!(username: params[:username])
    @current_locale = params[:locale] || I18n.locale
  end
end
```

## File: `app/controllers/search_controller.rb`

```
class SearchController < ApplicationController
  def index
    @search_keyword = params[:q]
    @articles = if @search_keyword.present?
                  Article.published
                    .where(locale: params[:locale])
                    .search(@search_keyword)
                    .includes(:category, :tags)
                    .order(published_at: :desc)
                    .page(params[:page]).per(10)
    else
                  Article.none.page(1)
    end
  end
end
```

## File: `app/views/articles/index.html.slim`

```
/ 現在の絞り込み条件表示
- if @filter.current_category || @filter.current_tags&.any?
  .filter-status
    | 現在の絞り込み: 
    - if @filter.current_category
      strong #{@filter.current_category.name}
    - if @filter.current_tags&.any?
      | タグ: 
      - @filter.current_tags.each do |tag|
        strong #{tag.name}
        | 　
    = link_to "すべてクリア", articles_path(locale: params[:locale])

/ 記事一覧
- @articles.each do |article|
  .article-item.mb-8.p-6.border-b.border-gray-500
    .article-header.max-w-3xl.mx-auto
      h2.text-4xl.font-extrabold.mb-4.mt-8.text-gray-900.border-b.border-gray-500.pb-2
        = link_to article.title, user_article_path(article.user.username, article.id, locale: params[:locale])

      .article-meta.pb-3.mb-4
        - if article.category.present?
          p.pb-2
            | カテゴリ: 
            = link_to article.category.name, user_articles_path(params[:username], @filter.filter_params.merge(category_id: article.category.id))

        = render 'shared/article_tags', article: article, filter_params: @filter.filter_params

      .meta-content-divider.text-center.mx-8
        span.text-gray-400.text-xl • • •

    .article-content.medium-container style="all: revert;"
      div class="medium"
        = article.content_html

    .article-meta.max-w-3xl.mx-auto.text-right
      p
        | 投稿日: 
        = article.published_at&.strftime('%Y年%m月%d日')
      p
        | 最終更新日: 
        = article.updated_at&.strftime('%Y年%m月%d日')

      - if article.translation.present?
        p= link_to "#{article.locale == 'ja' ? 'English' : '日本語'}版", user_article_path(article.translation.user.username, article.translation.id, locale: article.translation.locale)

= paginate @articles
```

## File: `app/views/articles/show.html.slim`

```
.article-items
  .article-title.max-w-5xl.mx-auto
    h1.text-4xl.font-extrabold.mb-8.text-gray-900
      = @article.title
  
  .article-meta.max-w-5xl.mx-auto.mb-4.border-b.border-gray-500
    .flex.items-center.mb-2
      span.w-20.text-gray-500.text-right
        | 投稿日
      span.w-4.text-gray-500.text-center
        | :
      span.text-gray-500
        = @article.published_at&.strftime('%Y年%m月%d日')

    .flex.items-center.mb-2
      span.w-20.text-gray-500.text-right
        | 更新日
      span.w-4.text-gray-500.text-center
        | :
      span.text-gray-500
        = @article.updated_at&.strftime('%Y年%m月%d日')

    .flex.items-center.mb-2
      - if @article.category.present?
        span.w-20.text-gray-500.text-right
          | カテゴリ
        span.w-4.text-gray-500.text-center
          | :
        span.text-gray-500.hover:text-gray-800
          = link_to @article.category.name, user_articles_path(locale: params[:locale], category_id: @article.category.id)

    .flex.items-center.mb-2
      span.w-20.text-gray-500.text-right
        | タグ
      span.w-4.text-gray-500.text-center
        | :
      span
        = render 'shared/article_tags', article: @article, filter_params: {}

    - if @article.translation.present?
      .flex.items-center.mb-2
        span.w-20.text-gray-500.text-right
          | 翻訳
        span.w-4.text-gray-500.text-center
          | :
        span
          = link_to "#{@article.locale == 'ja' ? 'English' : '日本語'}版", user_article_path(@article.translation.user.username, @article.translation.id, locale: @article.translation.locale), class: "pb-2 block text-gray-500 hover:text-gray-800"

  .article-content style="all: revert;"
    div class="medium-wide"
      = @article.content_html

/.section-devider.my-16.max-w-5xl.mx-auto
/  .border-t.border-gray-600

.section-divider.my-16.max-w-5xl.mx-auto.text-center
  .flex.items-center.justify-center.gap-4
    .border-t.border-gray-600.flex-1
    span.text-sm.italic.text-gray-600.px-4 End of the article
    .border-t.border-gray-600.flex-1

.comment-section
  .comments.max-w-5xl.mx-auto
    - if @article.comments.exists?
      - @article.comments.order(created_at: :desc).each.with_index(1) do |comment, index|
        .comment.mb-8.pb-4.border-b.border-gray-500
          p.mb-2.font-semibold
            | コメント#{index}:
          .mb-2
            - if comment.website.present?
              = link_to comment.author_name, comment.website, target: "_blank"
            - else
              = comment.author_name
          p.text-sm.text-gray-500.mb-2= comment.created_at.strftime('%Y年%m月%d日 %H:%M')
          .text-gray-700= simple_format(comment.content)
    - else
      p コメントはまだありません。

  .comment-form.max-w-5xl.mx-auto.py-8
    = form_with user: user_article_comments_path(@article.user.username, @article.id), local: true do |f|
      .flex.flex-col.w-1/2.mb-2
        = f.label :author_name, "お名前:", class: "mb-2"
        = f.text_field :author_name, required: true, class: "border-0 border-b border-gray-600 focus:outline-none"
      .flex.flex-col.w-1/2.mb-2
        = f.label :website, "ウェブサイト（任意）:", class: "mb-2"
        = f.url_field :website, class: "border-0 border-b border-gray-600 focus:outline-none"
      .flex.flex-col.w-1/2.mb-2
        = f.label :content, "コメント:", class: "mb-2"
        = f.text_area :content, rows: 5, required: true, class: "border border-gray-600 focus:outline-none"
      
      = f.submit "コメントを投稿", class: "px-4 py-2 border border-gray-300 bg-white cursor-pointer text-base rounded hover:bg-gray-200 transition-colors"
```

## File: `app/views/comments/new.html.slim`

```
h1 Comments#new
p Find me in app/views/comments/new.html.slim
```

## File: `app/views/dashboard/articles/_article_row.slim`

```
.flex.justify-between.items-center
  .flex-grow
    .font-semibold= article_data.title
    .text-sm.text-gray-500
      = article_data.locale == "ja" ? "日本語" : "English"
      | ・
      = article_data.category&.name || '未設定'
      | ・
      = article_data.published_at&.strftime("%Y-%m-%d")
      | ・
      = article_data.status == "draft" ? "下書き" : "公開"
      - if article_data.original? && article_data.has_translation?
        | ・翻訳済み
      - if article_data.translated?
        | ・翻訳元: #{article_data.original_article.title}
        /| ・翻訳元: 要チェック 

  .flex.space-x-2.ml-4
    - if article_data.translated?
      = link_to "翻訳編集", edit_dashboard_article_translation_path(article_data.original_article, locale: params[:locale]), class: "text-gray-600 hover:text-gray-800"
    - else
      = link_to "編集", edit_dashboard_article_path(article_data, locale: params[:locale]), class: "text-gray-600 hover:text-gray-800"
    - if article_data.translation.blank? && article_data.original?
      span.text-gray-400 |
      = link_to "翻訳作成", new_dashboard_article_translation_path(article_data, locale: params[:locale]), class: "text-gray-600 hover:text-gray-800"
```

## File: `app/views/dashboard/articles/_form.html.slim`

```
- if article.errors.any?
  h4 エラーが発生しました:
  ul
    - article.errors.full_messages.each do |message|
      li= message

div data-controller="markdown-preview image-upload layout-switcher" data-markdown-preview-url-value=dashboard_preview_path(locale: params[:locale]) data-layout-switcher-translation-mode-value=is_translation class="layout-switcher"

  div data-layout-switcher-target="buttons" class="layout-buttons flex gap-1 justify-center mb-2"
    button.layout-button type="button" data-action="click->layout-switcher#switchToSplit" data-mode="split" ⚏
    button.layout-button type="button" data-action="click->layout-switcher#switchToTextOnly" data-mode="text-only" ☰
    button.layout-button type="button" data-action="click->layout-switcher#switchToPreviewOnly" data-mode="preview-only" ⚇
    - if is_translation
      button.layout-button type="button" data-action="click->layout-switcher#switchToOriginalPreview" data-mode="original-preview" 原




  div class= "relative flex gap-5 h-screen"
    div data-layout-switcher-target="textArea" class="flex-1 pr-5 flex flex-col h-full text-area"

      = form_with model: article, url: form_url, local: true do |f|
        div class="flex items-center gap-4 mb-3"
          p
            = f.select :locale, options_for_select([["日本語", "ja"], ["English", "en"]], article.locale), {}, { disabled: locale_disabled, class: "text-gray-600 border border-gray-400 rounded" }
          p
            = f.select :status, options_for_select([["下書き", "draft"],["公開", "published"]], article.status), {}, class: "text-gray-600 border border-gray-400 rounded"

          - case button_type
          - when "new"
            = f.submit "記事を作成", class: "bg-gray-500 hover:bg-gray-600 rounded text-sm py-1 px-2 text-white"
          - when "edit"
            = f.submit "更新", class: "bg-blue-500 hover:bg-blue-600 rounded text-sm py-1 px-2 text-white"
            = link_to "キャンセル", dashboard_articles_path, class: "bg-gray-500 hover:bg-gray-600 rounded text-sm py-1 px-2 text-white ml-2"
            = link_to "削除", dashboard_article_path(article), class: "bg-red-500 hover:bg-red-600 rounded text-sm py-1 px-2 text-white ml-2", data: { "turbo-method": "delete", "turbo-confirm": "本当に削除しますか？" }
          - when "translation"
            = f.submit "翻訳を作成", class: "bg-green-500 hover:bg-green-600 rounded text-sm py-1 px-2 text-white"
            = link_to "キャンセル", dashboard_article_path(original_article), class: "bg-gray-500 hover:bg-gray-600 rounded text-sm py-1 px-2 text-white ml-2"
          

        div class="ml-auto flex gap-2"
          p
            = f.select :category_id, options_from_collection_for_select(Category.for_locale(article.locale || "ja"), :id, :name, article.category_id), { prompt: "---" }, { class: "text-gray-400 focus:outline-none", required: false }

          p
            = f.text_field :tag_list, placeholder: "tags", class: "text-gray-600 focus:outline-none"
          p
            button type="button" data-action="click->image-upload#selectImage" style="margin-bottom: 10px"
            | 📷

        p
          = f.text_field :title, required: true,
            class: "w-full border-b border-gray-400 placeholder-gray-400 p-2 focus:border-gray-400 focus:outline-none mb-3",
            placeholder: "title",
            data: { field: "title", action: "input->markdown-preview#preview" }
            
          = f.text_area :content, required: true, style: "width: 100%; padding-bottom: 36rem;", data: { markdown_preview_target: "input", action: "input->markdown-preview#preview", image_upload_target: "textarea" }, class: "px-3 py-2 border-0 focus:ring-0 focus:outline-none focus:border-[1px] focus:border-gray-300"

    div class="absolute top-0 bottom-0 left-1/2 w-[1px] bg-gray-400 layout-divider"

    div data-layout-switcher-target="preview" class="flex-1 pl-5 h-full overflow-hidden hover:overflow-y-auto preview-area"
      .medium-container style="all: revert;"
        div data-markdown-preview-target="titlePreview" class="medium title-preview"
          h1 プレビュータイトル
        div data-markdown-preview-target="preview" class="medium" style="padding-bottom: 36rem;"
          p プレビューがここに表示されます

    - if is_translation
      div data-layout-switcher-target="originalPreview" class="flex-1 pl-5 h-full overflow-hidden hover:overflow-y-auto original-preview-area"
        .original-content style="all: revert;"
          div class="medium"
            .original-title
              h1= @original_article.title
            .original-body
              = @original_article.content_html
```

## File: `app/views/dashboard/articles/edit.html.slim`

```
= render "form",
  article: @article,
  form_url: dashboard_article_path(@article),
  locale_disabled: true,
  button_type: "edit",
  is_translation: false
```

## File: `app/views/dashboard/articles/index.html.slim`

```
= link_to "新しい記事を作成", new_dashboard_article_path(locale: params[:locale]), class: "text-blue-500 hover:text-blue-600 inline-block p-3"

.space-y-6
  - @original_articles.each do |article|
    .p-4.border.border-gray-200.rounded-lg.shadow-sm.bg-white
      .space-y-4
        .p-3
          = render "dashboard/articles/article_row", article_data: article
        .span.border-b.border-gray-300
        - if article.translation.present?
          .p-3
            = render "dashboard/articles/article_row", article_data: article.translation
        - else
          .p-3.text-gray-500
            | 未翻訳

= paginate @original_articles
```

## File: `app/views/dashboard/articles/new.html.slim`

```
= render 'form',
  article: @article,
  form_url: dashboard_articles_path,
  locale_disabled: false,
  button_type: "new",
  is_translation: false
```

## File: `app/views/dashboard/articles/show.html.slim`

```
h1 Admin::Articles#show
p Find me in app/views/admin/articles/show.html.slim

h1
  = @article.title

  h2
    = @article.content

```

## File: `app/views/dashboard/blog_settings/edit.html.slim`

```
h1.text-2xl.font-bold.mb-6 ブログ外観設定

= form_with model: [:dashboard, @blog_setting], url: dashboard_blog_setting_path, local: true, multipart: true do |f|
  .space-y-6
    div
      = f.label :blog_title, "ブログタイトル", class: "block text-sm font-medium text-gray-700 mb-2"
      = f.text_field :blog_title, placeholder: "My Bilingual Blog", class: "w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-1 focus:ring-blue-500"
    
    div
      = f.label :blog_subtitle, "サブタイトル", class: "block text-sm font-medium text-gray-700 mb-2"
      = f.text_field :blog_subtitle, placeholder: "素晴らしいブログの説明", class: "w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-1 focus:ring-blue-500"
    
    div
      = f.label :theme_color, "テーマカラー", class: "block text-sm font-medium text-gray-700 mb-2"
      .grid.grid-cols-2.md:grid-cols-4.gap-3
        .theme-option
          = f.radio_button :theme_color, "blue", id: "theme_blue", class: "sr-only"
          = f.label :theme_blue, class: "flex flex-col items-center p-3 border-2 rounded-lg cursor-pointer hover:bg-gray-50 border-gray-300"
            .w-8.h-8.bg-blue-500.rounded-full.mb-2
            span.text-sm.font-medium ブルー
        
        .theme-option
          = f.radio_button :theme_color, "green", id: "theme_green", class: "sr-only"
          = f.label :theme_green, class: "flex flex-col items-center p-3 border-2 rounded-lg cursor-pointer hover:bg-gray-50 border-gray-300"
            .w-8.h-8.bg-green-500.rounded-full.mb-2
            span.text-sm.font-medium グリーン
        
        .theme-option
          = f.radio_button :theme_color, "purple", id: "theme_purple", class: "sr-only"
          = f.label :theme_purple, class: "flex flex-col items-center p-3 border-2 rounded-lg cursor-pointer hover:bg-gray-50 border-gray-300"
            .w-8.h-8.bg-purple-500.rounded-full.mb-2
            span.text-sm.font-medium パープル
        
        .theme-option
          = f.radio_button :theme_color, "gray", id: "theme_gray", class: "sr-only"
          = f.label :theme_gray, class: "flex flex-col items-center p-3 border-2 rounded-lg cursor-pointer hover:bg-gray-50 border-gray-300"
            .w-8.h-8.bg-gray-500.rounded-full.mb-2
            span.text-sm.font-medium グレー
    
    div
      = f.label :header_image, "ヘッダー画像", class: "block text-sm font-medium text-gray-700 mb-2"
      - if @blog_setting.header_image.attached?
        .mb-3
          = image_tag @blog_setting.header_image, class: "w-full h-32 object-cover rounded-lg border"
          p.text-sm.text-gray-500.mt-1 現在のヘッダー画像
      = f.file_field :header_image, accept: "image/*", class: "block w-full text-sm text-gray-500 file:mr-4 file:py-2 file:px-4 file:rounded file:border-0 file:text-sm file:font-semibold file:bg-blue-50 file:text-blue-700 hover:file:bg-blue-100"
      p.text-xs.text-gray-500.mt-1 推奨サイズ: 1200x300px
    
    .flex.gap-3
      = f.submit "設定を保存", class: "bg-blue-500 hover:bg-blue-600 text-white px-6 py-2 rounded-md transition-colors"
      = link_to "キャンセル", dashboard_articles_path, class: "bg-gray-500 hover:bg-gray-600 text-white px-6 py-2 rounded-md transition-colors"
```

## File: `app/views/dashboard/categories/_category_table.html.slim`

```
- if categories.any?
  table
    thead
      tr
        th ID
        th カテゴリ名
        th 説明
        th 記事数
        th アクション
    tbody
      - categories.each do |category|
        tr
          td= category.id
          td= category.name
          td= truncate(category.description, length: 50) if category.description.present?
          td= category.articles_count || 0
          td
            = link_to "編集", edit_dashboard_category_path(category)
            = " | "
            = link_to "削除", dashboard_category_path(category),
                      data: { turbo_method: :delete, turbo_confirm: "削除しますか？"}
- else
  p カテゴリがありません
```

## File: `app/views/dashboard/categories/edit.html.slim`

```
h1 カテゴリを編集

- if @category.errors.any?
  .errors
    h4 エラーが発生しました:
    ul
      - @category.errors.full_messages.each do |message|
        li= message

= form_with model: [:dashboard, @category], local: true do |f|
  p
    = f.label :name, "カテゴリ名"
    = f.text_field :name, required: true, style: "width: 100%;"

  p
    = f.label :description, "説明(任意)"
    = f.text_area :description, row:4, style: "width: 100%;"

  p
    = f.label :locale, "言語"
    = f.select :locale, options_for_select([["日本語", "ja"], ["English", "en"]], @category.locale), {}, { disabled: true, style: "background-color: #f5f5f5;" }
    small style="color: #666; display: block; margin-top: 5px;"
      | 言語は変更できません

  .actions
    = f.submit "カテゴリを更新"
    = link_to "キャンセル", dashboard_categories_path
    = link_to "削除", dashboard_category_path(@category),
             data: { turbo_method: :delete, turbo_confirm: "このカテゴリを削除しますか？" }
```

## File: `app/views/dashboard/categories/index.html.slim`

```
.tab-container data-controller="category-tabs"
  .tab-buttons
    button.tab-button.active data-action="click->category-tabs#switchTab" data-target="ja" data-category-tabs-target="button"
      | 日本語 (#{category_count_for_locale("ja")})
    button.tab-button data-action="click->category-tabs#switchTab" data-target="en" data-category-tabs-target="button"
      | English (#{category_count_for_locale("en")})
  .tab-content.active data-category-tabs-target="content" data-tab="ja"
    = link_to "日本語カテゴリを作成", new_dashboard_category_path(locale: "ja"), 
      style: "margin-bottom: 20px; display: inline-block;"
    = render "category_table", categories: @ja_categories

  .tab-content data-category-tabs-target="content" data-tab="en"
    = link_to "英語カテゴリを作成", new_dashboard_category_path(locale: "en"), style: "margin-bottom: 20px; display: inline-block;"
    = render "category_table", categories: @en_categories
```

## File: `app/views/dashboard/categories/new.html.slim`

```
h1 新しいカテゴリを作成

- if @category.errors.any?
  .errors
    h4 エラーが発生しました:
    ul
      - @category.errors.full_messages.each do |message|
        li= message

= form_with model: [:dashboard, @category], local: true do |f|
  p
    = f.label :name, "カテゴリ名"
    = f.text_field :name, required: true, style: "width: 100%;"

  p
    = f.label :description, "説明(任意)"
    = f.text_area :description, rows: 4, style: "width: 100%;"

  p
    = f.label :locale, "言語"
    = f.select :locale, options_for_select([["日本語", "ja"], ["English", "en"]], @category.locale), {}, { disabled: true, style: "background-color: #f5f5f5" }
    small style="color: #666; display: block; margin-top: 5px;"
      | 言語は作成時に決定され、後から変更できません

  .actions
    = f.submit "カテゴリを作成"
    = link_to "キャンセル", dashboard_categories_path
```

## File: `app/views/dashboard/comments/index.html.slim`

```
h1 dashboard::Comments#index
p Find me in app/views/dashboard/comments/index.html.slim

table
  thead
    tr
      th 記事タイトル
      th コメント者
      th コメント内容(抜粋)
      th 投稿日
      th アクション
  tbody
    - @comments.each do |comment|
      tr
        td= link_to comment.article.title, user_article_path(comment.article.user.username, comment.article.id, locale: comment.article.locale)
        td= comment.author_name
        td= truncate(comment.content, length: 50)
        td= comment.created_at.strftime('%Y/%m/%d %H:%M')
        td
          = link_to "詳細", dashboard_comment_path(comment, locale: params[:locale])
          = link_to "削除", dashboard_comment_path(comment, locale: params[:locale]), 
                    data: { turbo_method: :delete, turbo_confirm: "削除しますか？" }

= paginate @comments
```

## File: `app/views/dashboard/comments/show.html.slim`

```
h1 コメント詳細

h3 記事情報
p
  strong タイトル: 
  = link_to @comment.article.title, user_article_path(@comment.article, locale: @comment.article.locale)
p
  strong 言語: 
  = @comment.article.locale == 'ja' ? '日本語' : 'English'

h3 コメント情報
p
  strong 投稿者: 
  = @comment.author_name
p
  strong 投稿日: 
  = @comment.created_at.strftime('%Y年%m月%d日 %H:%M')
- if @comment.website.present?
  p
    strong ウェブサイト: 
    = link_to @comment.website, @comment.website, target: "_blank"

h3 コメント内容
= simple_format(@comment.content)

= link_to "削除", dashboard_comment_path(@comment, locale: params[:locale]), data: { turbo_method: :delete, turbo_confirm: "削除しますか？" }
= link_to "一覧に戻る", dashboard_comments_path(locale: params[:locale])
```

## File: `app/views/dashboard/profiles/edit.html.slim`

```
.mb-4
  = link_to "👁️ 公開プロフィールを確認", user_profile_path(current_user.username, locale: I18n.locale), target: "_blank", class: "text-blue-500 hover:text-blue-600 text-sm"

h1.text-2xl.font-bold.mb-6 プロフィール編集

= form_with model: [:dashboard, @user], url: dashboard_profile_path, local: true, multipart: true do |f|
  .space-y-6
    div
      = f.label :avatar, "アイコン画像", class: "block text-sm font-medium text-gray-700 mb-2"
      = f.file_field :avatar, accept: "image/*", class: "block w-full text-sm text-gray-500 file:mr-4 file:py-2 file:px-4 file:rounded file:border-0 file:text-sm file:font-semibold file:bg-blue-50 file:text-blue-700 hover:file:bg-blue-100"
    
    div
      = f.label :nickname_ja, "ニックネーム", class: "block text-sm font-medium text-gray-700 mb-2"
      .grid.grid-cols-2.gap-4
        div
          = f.label :nickname_ja, "日本語", class: "block text-xs text-gray-500 mb-1"
          = f.text_field :nickname_ja, class: "w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-1 focus:ring-blue-500"
        div
          = f.label :nickname_en, "English", class: "block text-xs text-gray-500 mb-1"
          = f.text_field :nickname_en, class: "w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-1 focus:ring-blue-500"
    
    div
      = f.label :bio_ja, "自己紹介", class: "block text-sm font-medium text-gray-700 mb-2"
      .grid.grid-cols-1.gap-4
        div
          = f.label :bio_ja, "日本語", class: "block text-xs text-gray-500 mb-1"
          = f.text_area :bio_ja, rows: 3, class: "w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-1 focus:ring-blue-500"
        div
          = f.label :bio_en, "English", class: "block text-xs text-gray-500 mb-1"
          = f.text_area :bio_en, rows: 3, class: "w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-1 focus:ring-blue-500"
    
    div
      = f.label :location_ja, "居住地", class: "block text-sm font-medium text-gray-700 mb-2"
      .grid.grid-cols-2.gap-4
        div
          = f.label :location_ja, "日本語", class: "block text-xs text-gray-500 mb-1"
          = f.text_field :location_ja, class: "w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-1 focus:ring-blue-500"
        div
          = f.label :location_en, "English", class: "block text-xs text-gray-500 mb-1"
          = f.text_field :location_en, class: "w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-1 focus:ring-blue-500"
    
    div
      = f.label :website, "ウェブサイト", class: "block text-sm font-medium text-gray-700 mb-2"
      = f.url_field :website, placeholder: "https://", class: "w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-1 focus:ring-blue-500"
    
    .grid.grid-cols-1.md:grid-cols-3.gap-4
      div
        = f.label :twitter_handle, "X (Twitter)", class: "block text-sm font-medium text-gray-700 mb-2"
        = f.text_field :twitter_handle, placeholder: "@username", class: "w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-1 focus:ring-blue-500"
      
      div
        = f.label :facebook_handle, "Facebook", class: "block text-sm font-medium text-gray-700 mb-2"
        = f.text_field :facebook_handle, placeholder: "username", class: "w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-1 focus:ring-blue-500"
      
      div
        = f.label :linkedin_handle, "LinkedIn", class: "block text-sm font-medium text-gray-700 mb-2"
        = f.text_field :linkedin_handle, placeholder: "username", class: "w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-1 focus:ring-blue-500"
    
    .flex.gap-3
      = f.submit "更新", class: "bg-blue-500 hover:bg-blue-600 text-white px-6 py-2 rounded-md transition-colors"
      = link_to "キャンセル", dashboard_articles_path, class: "bg-gray-500 hover:bg-gray-600 text-white px-6 py-2 rounded-md transition-colors"
```

## File: `app/views/dashboard/translations/edit.html.slim`

```
= render "dashboard/articles/form",
  article: @translation,
  form_url: dashboard_article_translation_path(@original_article),
  locale_disabled: true,
  button_type: "edit",
  is_translation: true
```

## File: `app/views/dashboard/translations/new.html.slim`

```
= render 'dashboard/articles/form',
  article: @translation,
  original_article: @original_article,
  form_url: dashboard_article_translation_path(@original_article),
  locale_disabled: true,
  button_type: "translation",
  is_translation: true
```

## File: `app/views/dashboard/translations/show.html.slim`

```
h1 Admin::Translations#show
p Find me in app/views/admin/translations/show.html.slim
```

## File: `app/views/layouts/application.html.erb`

```
<!DOCTYPE html>
<html class="<%= @blog_setting&.theme_color || 'blue' %>-theme">
  <head>
    <title><%= @blog_setting&.display_title || "Bilingual Brog" %></title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <meta name="apple-mobile-web-app-capable" content="yes">
    <meta name="mobile-web-app-capable" content="yes">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>

    <%= yield :head %>

    <%# Enable PWA manifest for installable apps (make sure to enable in config/routes.rb too!) %>
    <%#= tag.link rel: "manifest", href: pwa_manifest_path(format: :json) %>

    <link rel="icon" href="/icon.png" type="image/png">
    <link rel="icon" href="/icon.svg" type="image/svg+xml">
    <link rel="apple-touch-icon" href="/icon.png">

    <%# Includes all stylesheet files in app/assets/stylesheets %>
    <%= stylesheet_link_tag :app, "data-turbo-track": "reload" %>
    <%= javascript_importmap_tags %>
  </head>

  <body class="text-lg bg-gray-100">
    <!-- ページヘッダー -->
    <header class="site-header mb-4">
      <div class="header-container w-full">
        <div class="header-content">
          <nav class="main-nav w-full bg-gray-200">
            <nav class="nav-inner flex max-w-6xl mx-auto items-center justify-end gap-4 h-12 px-6">

            <!-- SNS -->
              <div class="sns-icons flex gap-3">
                <%= link_to "Facebook", "#", class: "sns-link text-gray-600 hover:text-gray-900" %>
                <%= link_to "X", "#", class: "sns-link text-gray-600 hover:text-gray-900" %>
              </div>

            <!-- 言語切替 -->
            <% link_label = params[:locale] == "ja" ? "EN" : "JP" %>
            <% link_locale = params[:locale] == "ja" ? "en" : "ja" %>
            <% if action_name == "show" && @article&.translation.present? %>
              <%= link_to "#{link_label}", user_article_path(@article.translation.user.username, @article.translation.id, locale: "#{link_locale}"), class: "px-2 py-1 border border-gray-300 bg-white hover:bg-gray-100 font-medium rounded" %>
            <% elsif action_name == "show" && @article&.original_article.present? %>
              <%= link_to "#{link_label}", user_article_path(@article.original_article.user.username, @article.original_article.id, locale: "#{link_locale}"), class: "px-2 py-1 border border-gray-300 bg-white hover:bg-gray-100 font-medium rounded" %>
            <% elsif controller_name == "profiles" && action_name == "show" %>
              <%= link_to "#{link_label}", user_profile_path(params[:username], locale: "#{link_locale}"), class: "px-2 py-1 border border-gray-300 bg-white hover:bg-gray-100 font-medium rounded" %>
            <% else %>
              <%= link_to "#{link_label}", user_articles_path(params[:username], locale: "#{link_locale}"), class: "px-2 py-1 border border-gray-300 bg-white hover:bg-gray-100 font-medium rounded" %>
            <% end %>

             <!-- 検索フォームを追加 -->
            <div class="header-search">
              <%=form_with url: search_path(locale: params[:locale] || 'ja'), method: :get, local: true, class: "search-form flex items-center gap-2" do |f| %>
                <%= f.text_field :q,
                    placeholder: (params[:locale] == "ja" ? "記事を検索..." : "Search article..."),
                    class: "search-input w-64 border border-gray-300 rounded-md focus:outline-none focus:ring-1 focus:ring-gray-400 bg-white px-4 py-1",
                    value: params[:q] %>
                <%= f.submit (params[:locale] == "ja" ? "検索" : "Search"),
                    class: "search-button bg-gray-700 text-white rounded-md hover:bg-gray-500 transition px-4 py-1" %>
              <% end %>
            </div>
            <div class="flex items-center gap-4">
              <% if user_signed_in? %>
                <div class="flex items-center gap-2">
                  <% if current_user.avatar.attached? %>
                    <%= image_tag current_user.avatar, class: "w-8 h-8 rounded-full" %>
                  <% else %>
                    <div class="w-8 h-8 bg-gray-300 rounded-full flex items-center justify-center text-sm">
                      <%= current_user.display_name.first %>
                    </div>
                  <% end %>
                  <%= link_to current_user.display_name, user_profile_path(current_user.username), locale: params[:locale], class: "" %>
                </div>
              <% end %>
            </div>
            </nav>
           </nav>
          <div class="text-center py-10">
            <%= link_to (@blog_setting&.display_title || "My Bilingual Blog"), root_path, class: "blog-title text-4xl font-bold py-4 inline-block" %>
            <% if @blog_setting&.display_subtitle.present? %>
              <p class="text-lg text-gray-600 mt-2"><%= @blog_setting.display_subtitle %></p>
            <% end %>
          </div>
          <div class="max-w-6xl mx-auto px-6 border-b border-gray-500"></div>

        </div>
      </div>
    </header>

    <% flash.each do |type, message| %>
      <div class="flash-message text-red-700 p-4 mb-4 max-w-6xl text-center">
        <p><%= message %></p>
      </div>
    <% end %>

    <!-- メインコンテンツ -->
    <main class="main-content">
      <div class="content-container max-w-6xl mx-auto px-6">
        <%= yield %>
      </div>
    </main>

    <!-- フッター -->
    <footer class="site-footer">
      <div class="footer-container max-w-6xl mx-auto px-6 bg-gray-100">
        <p>© 2025 Bilingual Blog. All rights reserved.</p>
      </div>
    </footer>
  </body>
</html>
```

## File: `app/views/layouts/dashboard.html.erb`

```
<!-- app/views/layouts/dashboard.html.erb -->
<!DOCTYPE html>
<html>
  <head>
    <title>Bilingual Blog - 管理画面</title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>

    <%= stylesheet_link_tag "medium-style", "data-turbo-track": "reload" %>
    <%= stylesheet_link_tag "syntax-highlighting", "data-turbo-track": "reload" %>
    <%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>
    <%= stylesheet_link_tag "tailwind", "data-turbo-track": "reload" %>

    <%= javascript_importmap_tags %>
  </head>
  <body class="text-lg bg-gray-100">
    <header class="mb-4 w-full bg-gray-200">
      <div class="dashboard-nav flex max-w-6xl mx-auto items-center justify-between h-12">
        <div class="nav-left flex">
        <h1>
          <%= link_to "管理画面", dashboard_articles_path, class: "mx-2 text-gray-700 hover:text-gray-900 text-bold" %>
        </h1>
          <div class="nav-links mx-2">
            <%= link_to "カテゴリ", dashboard_categories_path, class: "mx-2 text-gray-500 hover:text-gray-700" %>
            <%= link_to "コメント", dashboard_comments_path, class: "mx-2 text-gray-500 hover:text-gray-700" %>
            <%= link_to "プロフィール", edit_dashboard_profile_path, class: "mx-2 text-gray-500 hover:text-gray-700" %>
            <%= link_to "ブログ設定", edit_dashboard_blog_setting_path, class: "mx-2 text-gray-500 hover:text-gray-700" %>
            <%= link_to "サイトを見る", user_articles_path(current_user.username, locale: I18n.locale), target: "_blank", class: "mx-2 text-gray-500 hover:text-gray-700" %>
          </div>
        </div>
        
        <div class="user-info">
          <% if user_signed_in? %>
            <span class="text-red-500">
              ログイン中: <%= current_user.email %>
            </span>
            <%= link_to "ログアウト", destroy_user_session_path, 
              data: { "turbo-method": "delete" },
              class: "mx-2 text-gray-500 hover:text-gray-700"
                %>
          <% else %>
            <%= link_to "ログイン", new_user_session_path %>
          <% end %>
        </div>
      </div>
    </header>

    <% flash.each do |type, message| %>
      <div class="flash-message text-green-700 p-4 mb-4 max-w-6xl text-center">
        <p><%= message %></p>
      </div>
    <% end %>

    <div class="container max-w-6xl mx-auto px-6">
        <%= yield %>
    </div>
  </body>
</html>
```

## File: `app/views/layouts/mailer.html.erb`

```
<!DOCTYPE html>
<html>
  <head>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
    <style>
      /* Email styles need to be inline */
    </style>
  </head>

  <body>
    <%= yield %>
  </body>
</html>
```

## File: `app/views/layouts/mailer.text.erb`

```
<%= yield %>
```

## File: `app/views/profiles/show.html.slim`

```
.profile-header.mb-8
  .flex.items-center.gap-6
    - if @user.avatar.attached?
      = image_tag @user.avatar, class: "w-24 h-24 rounded-full"
    - else
      .w-24.h-24.bg-gray-300.rounded-full.flex.items-center.justify-center
        span.text-3xl.text-gray-600 #{@user.display_name.first}

    div
      h1.text-3xl.font-bold= @user.display_name(@current_locale)
      - if @user.localized_location(@current_locale).present?
        p.text-gray-600 #{@user.localized_location(@current_locale)}

      - if @user.localized_bio(@current_locale).present?
        p.mt-2= simple_format(@user.localized_bio(@current_locale))

      - if @user.website.present? || @user.twitter_handle.present? || @user.facebook_handle.present?

        .flex.gap-3.mt-4
          - if @user.website.present?
            = link_to @user.website, target: "_blank" do
              | 🌐 Website
          - if @user.twitter_handle.present?
            = link_to "https://x.com/#{@user.twitter_handle.delete('@')}", target: "_blank" do
              | X
          - if @user.facebook_handle.present?
            = link_to "https://facebook.com/#{@user.facebook_handle}", target: "_blank" do
              | Facebook

```

## File: `app/views/pwa/manifest.json.erb`

```
{
  "name": "BilingualBrog",
  "icons": [
    {
      "src": "/icon.png",
      "type": "image/png",
      "sizes": "512x512"
    },
    {
      "src": "/icon.png",
      "type": "image/png",
      "sizes": "512x512",
      "purpose": "maskable"
    }
  ],
  "start_url": "/",
  "display": "standalone",
  "scope": "/",
  "description": "BilingualBrog.",
  "theme_color": "red",
  "background_color": "red"
}
```

## File: `app/views/pwa/service-worker.js`

```
// Add a service worker for processing Web Push notifications:
//
// self.addEventListener("push", async (event) => {
//   const { title, options } = await event.data.json()
//   event.waitUntil(self.registration.showNotification(title, options))
// })
//
// self.addEventListener("notificationclick", function(event) {
//   event.notification.close()
//   event.waitUntil(
//     clients.matchAll({ type: "window" }).then((clientList) => {
//       for (let i = 0; i < clientList.length; i++) {
//         let client = clientList[i]
//         let clientPath = (new URL(client.url)).pathname
//
//         if (clientPath == event.notification.data.path && "focus" in client) {
//           return client.focus()
//         }
//       }
//
//       if (clients.openWindow) {
//         return clients.openWindow(event.notification.data.path)
//       }
//     })
//   )
// })
```

## File: `app/views/search/index.html.slim`

```
h1= params[:locale] == 'ja' ? '検索結果' : 'Search Results'

/ 検索結果の表示
- if @search_keyword.present?
  p style="margin-bottom: 20px;"
    | 「#{@search_keyword}」の検索結果: #{@articles.total_count}件
    = link_to (params[:locale] == 'ja' ? '記事一覧に戻る' : 'Back to Articles'), user_articles_path(locale: params[:locale]), style: "margin-left: 20px;"
- else
  p= params[:locale] == 'ja' ? 'キーワードを入力してください' : 'Please enter a keyword'
  = link_to (params[:locale] == 'ja' ? '記事一覧に戻る' : 'Back to Articles'), user_articles_path(locale: params[:locale]), style: "margin-left: 20px;"
    
/ 記事一覧表示（articles/index.html.slim と同じ構造）
- @articles.each do |article|
  .article-item style="margin-bottom: 30px; padding: 20px; border: 1px solid #ddd;"
    h2= link_to article.title, user_article_path(article.user.username, article.id, locale: params[:locale])
    
    - if article.category.present?
      p
        | カテゴリ: 
        strong= article.category.name
    
    - if article.tags.any?
      p
        | タグ: 
        - article.tags.each_with_index do |tag, index|
          strong= tag.name
          - if index < article.tags.size - 1
            | , 
    
    .article-content= article.content_html
    p
      strong 投稿日: 
      = article.published_at&.strftime('%Y年%m月%d日')

= paginate @articles
```

## File: `app/views/shared/_article_tags.html.slim`

```
- if article.tags.any?
  .flex.items-center.gap-2
    / ここにステップ1でコピーしたSVGコードを貼り付ける
    / Tailwindクラス (w-4 h-4 text-gray-500 など) を追加してサイズと色を調整
    svg xmlns="www.w3.org" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-4 h-4 text-gray-500"
      path stroke-linecap="round" stroke-linejoin="round" d="M9.568 3H5.25A2.25 2.25 0 003 5.25v4.318c0 .597.237 1.17.659 1.591l9.581 9.581a4.5 4.5 0 006.364-6.364L10.12 4.06C9.7 3.639 9.127 3 9.568 3z"
      path stroke-linecap="round" stroke-linejoin="round" d="M6 6h.008v.008H6V6z"

    / 各タグのリンクを生成する部分
    .flex.flex-wrap.gap-2
      - article.tags.each do |t|
        = link_to user_articles_path(filter_params.merge(tag_id: t.id)), class: "bg-blue-100 text-blue-800 text-xs font-semibold px-2.5 py-0.5 rounded hover:bg-blue-200" do
          = t.name
```

## File: `config/routes.rb`

```
Rails.application.routes.draw do
  devise_for :users
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

# Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
# get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
# get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

# Defines the root path route ("/")
# root "posts#index"



# scope "/:locale", constraints: { locale: /ja|en/ } do
#   root "home#index"
#
#   get "/:username/articles", to: "articles#index", constraints: { username: /[^\/]+/ }, as: :user_articles
#   get "/:username/articles/:id", to: "articles#show", constraints: { username: /[^\/]+/ }, as: :user_article
#   post "/:username/articles/:article_id/comments", to: "comments#create", constraints: { username: /[^\/]+/ }, as: :user_article_comments
#   get "search", to: "search#index"
#   get ":username/profile", to: "profile#show", constraints: { username: /[^\/]+/ }, as: :user_profile
# end


scope "/:locale", constraints: { locale: /ja|en/ } do
  root "home#index"
  get "search", to: "search#index"

  scope "u" do
    get "/:username/articles", to: "articles#index", as: :user_articles
    get "/:username/articles/:id", to: "articles#show", as: :user_article
    post "/:username/articles/:article_id/comments", to: "comments#create", as: :user_article_comments
    get ":username/profile", to: "profiles#show", as: :user_profile
  end
end

namespace :dashboard do
  resources :articles do
    resource :translation, only: %i[show create update destroy new edit]
  end
  resources :comments, only: %i[index show destroy]
  resources :categories
  resource :preview, only: [ :create ]
  resources :images, only: [ :create ]
  resource :profile, only: %i[edit update]
  resource :blog_setting, only: %i[edit update]
end

get "/dashboard", to: redirect("/dashboard/articles")
get "/", to: redirect("/ja")
end
```

## File: `db/schema.rb`

```
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_12_09_080239) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "article_tags", force: :cascade do |t|
    t.bigint "article_id", null: false
    t.bigint "tag_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["article_id", "tag_id"], name: "index_article_tags_on_article_id_and_tag_id", unique: true
    t.index ["article_id"], name: "index_article_tags_on_article_id"
    t.index ["tag_id"], name: "index_article_tags_on_tag_id"
  end

  create_table "articles", force: :cascade do |t|
    t.string "title", null: false
    t.text "content", null: false
    t.string "locale", default: "ja", null: false
    t.integer "original_article_id"
    t.integer "status", default: 0
    t.datetime "published_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "category_id"
    t.bigint "user_id", null: false
    t.index ["category_id"], name: "index_articles_on_category_id"
    t.index ["original_article_id"], name: "index_articles_on_original_article_id"
    t.index ["published_at"], name: "index_articles_on_published_at"
    t.index ["user_id"], name: "index_articles_on_user_id"
  end

  create_table "blog_settings", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "blog_title"
    t.string "blog_subtitle"
    t.string "theme_color", default: "blue"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_blog_settings_on_user_id", unique: true
  end

  create_table "categories", force: :cascade do |t|
    t.string "name", null: false
    t.string "locale", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["locale"], name: "index_categories_on_locale"
    t.index ["name", "locale"], name: "index_categories_on_name_and_locale", unique: true
    t.index ["user_id"], name: "index_categories_on_user_id"
  end

  create_table "comments", force: :cascade do |t|
    t.bigint "article_id", null: false
    t.string "author_name", null: false
    t.text "content", null: false
    t.string "website"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["article_id"], name: "index_comments_on_article_id"
  end

  create_table "tags", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_tags_on_name", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "role", default: 0, null: false
    t.string "username", null: false
    t.string "website"
    t.string "twitter_handle"
    t.string "facebook_handle"
    t.string "linkedin_handle"
    t.string "nickname_ja"
    t.string "nickname_en"
    t.text "bio_ja"
    t.text "bio_en"
    t.string "location_ja"
    t.string "location_en"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role"], name: "index_users_on_role"
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "article_tags", "articles"
  add_foreign_key "article_tags", "tags"
  add_foreign_key "articles", "articles", column: "original_article_id", on_delete: :cascade
  add_foreign_key "articles", "categories"
  add_foreign_key "articles", "users"
  add_foreign_key "blog_settings", "users"
  add_foreign_key "categories", "users"
  add_foreign_key "comments", "articles"
end
```

## File: `db/seeds.rb`

```
puts "Starting to create seed data..."

Comment.destroy_all
Article.destroy_all
Category.destroy_all
User.destroy_all

puts "Creating users..."

# 管理者アカウント
admin_user = User.find_or_initialize_by(email: "admin@example.com")
admin_user.password = "password"
admin_user.password_confirmation = "password"
admin_user.role = :admin
admin_user.username = "admin"
admin_user.save!

# テスト用ユーザー
test_user = User.find_or_initialize_by(email: "test@example.com")
test_user.password = "password"
test_user.password_confirmation = "password"
test_user.role = :user
test_user.username = "testuser"
test_user.save!

puts "Creating categories..."

# カテゴリ作成（admin_userに紐付け）
ja_programming = admin_user.categories.create!(name: 'プログラミング', locale: 'ja', description: 'プログラミング関連の記事')
ja_daily = admin_user.categories.create!(name: '日常', locale: 'ja', description: '日常の出来事について')
ja_tech = admin_user.categories.create!(name: '技術Tips', locale: 'ja', description: '開発で役立つ技術情報')

en_programming = admin_user.categories.create!(name: 'Programming', locale: 'en', description: 'Articles about programming')
en_daily = admin_user.categories.create!(name: 'Daily Life', locale: 'en', description: 'About daily life')
en_tech = admin_user.categories.create!(name: 'Tech Tips', locale: 'en', description: 'Useful technical information')

categories_ja = [ ja_programming, ja_daily, ja_tech ]
categories_en = [ en_programming, en_daily, en_tech ]

puts "Creating articles..."

30.times do |i|
  category = categories_ja.sample  # ランダムにカテゴリを選択

  ja_article = admin_user.articles.create!(  # admin_user.articles.create!に変更
    title: "日本語記事#{i + 1}",
    locale: 'ja',
    content: <<~CONTENT,
      # プログラミング学習第#{i + 1}回
#{'      '}
      第#{i + 1}回目の**日本語記事**です。
#{'      '}
      ## 学習内容
      - Ruby基礎
      - Rails入門
      - `puts "Hello World"`

```ruby
      def hello
        puts "Hello, World! - #{i + 1}"
      end
```
#{'      '}
      **カテゴリ**: #{category.name}
    CONTENT
    status: :published,
    published_at: (30 - i).days.ago + rand(24).hours,
    category: category,
    tag_list: [ 'プログラミング', 'Ruby', 'Rails', '初心者', '学習' ].sample(rand(2..4)).join(', ')
  )

  # 偶数番号の記事には英語翻訳を追加
  if i.even?
    en_category = categories_en.sample

    admin_user.articles.create!(  # admin_user.articles.create!に変更
      title: "English Article #{i + 1}",
      locale: 'en',
      content: <<~CONTENT,
        # Programming Study Part #{i + 1}
#{'        '}
        This is the #{i + 1}th **English article**.
#{'        '}
        ## Learning Content
        - Ruby Basics
        - Rails Introduction
        - `puts "Hello World"`

```ruby
        def hello
          puts "Hello, World! - #{i + 1}"
        end
```
#{'        '}
        **Category**: #{en_category.name}
      CONTENT
      status: :published,
      published_at: ja_article.published_at,
      original_article: ja_article,
      category: en_category,
      tag_list: [ 'Programming', 'Ruby', 'Rails', 'Beginner', 'Learning' ].sample(rand(2..4)).join(', ')
    )
  end
end

# 下書き記事
3.times do |i|
  admin_user.articles.create!(  # admin_user.articles.create!に変更
    title: "下書き記事 #{i + 1}",
    locale: "ja",
    content: "この記事は準備中です...",
    status: :draft,
    category: categories_ja.sample
  )
end

# コメントのseed（新規追加）
puts 'Creating comment seed data...'

# 日本語記事へのコメント
Article.where(locale: 'ja', status: :published).each_with_index do |article, index|
  rand(1..2).times do |i|
    Comment.find_or_create_by(
      article: article,
      author_name: "コメント者#{index + 1}-#{i + 1}",
      content: "とても参考になりました。#{[ '勉強になります！', 'ありがとうございます。', '続きが楽しみです。', 'わかりやすい解説でした。' ].sample}"
    ) do |comment|
      # published_atがnilの場合はcreated_atを使用
      base_time = article.published_at || article.created_at
      comment.created_at = base_time + rand(1..10).days
    end
  end
end

# 英語記事へのコメント
Article.where(locale: 'en', status: :published).each_with_index do |article, index|
  rand(1..2).times do |i|
    Comment.find_or_create_by(
      article: article,
      author_name: "User#{index + 1}-#{i + 1}",
      content: "#{[ 'Great article!', 'Very helpful, thanks!', 'Looking forward to more.', 'Well explained.' ].sample}"
    ) do |comment|
      comment.website = [ '', 'https://example.com', 'https://github.com/user' ].sample
      # published_atがnilの場合はcreated_atを使用
      base_time = article.published_at || article.created_at
      comment.created_at = base_time + rand(1..7).days
    end
  end
end

puts "管理者ユーザーを作成しました: #{admin_user.email}"
puts "テストユーザーを作成しました: #{test_user.email}"
puts 'Admin user created!'
puts 'Login credentials:'
puts 'Email: admin@example.com'
puts 'Password: password'
puts '========================================='

puts 'Seed data creation completed!'
puts "Total Articles: #{Article.count}"
puts "Japanese Articles: #{Article.where(locale: 'ja').count}"
puts "English Articles: #{Article.where(locale: 'en').count}"
puts "Categories (ja): #{Category.where(locale: 'ja').count}"
puts "Categories (en): #{Category.where(locale: 'en').count}"
puts "Total Users: #{User.count}"
```

## File: `app/assets/builds/tailwind.css`

```
/*! tailwindcss v4.1.16 | MIT License | https://tailwindcss.com */
@layer properties{@supports (((-webkit-hyphens:none)) and (not (margin-trim:inline))) or ((-moz-orient:inline) and (not (color:rgb(from red r g b)))){*,:before,:after,::backdrop{--tw-space-y-reverse:0;--tw-space-x-reverse:0;--tw-border-style:solid;--tw-font-weight:initial;--tw-shadow:0 0 #0000;--tw-shadow-color:initial;--tw-shadow-alpha:100%;--tw-inset-shadow:0 0 #0000;--tw-inset-shadow-color:initial;--tw-inset-shadow-alpha:100%;--tw-ring-color:initial;--tw-ring-shadow:0 0 #0000;--tw-inset-ring-color:initial;--tw-inset-ring-shadow:0 0 #0000;--tw-ring-inset:initial;--tw-ring-offset-width:0px;--tw-ring-offset-color:#fff;--tw-ring-offset-shadow:0 0 #0000;--tw-outline-style:solid;--tw-blur:initial;--tw-brightness:initial;--tw-contrast:initial;--tw-grayscale:initial;--tw-hue-rotate:initial;--tw-invert:initial;--tw-opacity:initial;--tw-saturate:initial;--tw-sepia:initial;--tw-drop-shadow:initial;--tw-drop-shadow-color:initial;--tw-drop-shadow-alpha:100%;--tw-drop-shadow-size:initial}}}@layer theme{:root,:host{--font-sans:ui-sans-serif,system-ui,sans-serif,"Apple Color Emoji","Segoe UI Emoji","Segoe UI Symbol","Noto Color Emoji";--font-mono:ui-monospace,SFMono-Regular,Menlo,Monaco,Consolas,"Liberation Mono","Courier New",monospace;--color-red-500:oklch(63.7% .237 25.331);--color-red-600:oklch(57.7% .245 27.325);--color-red-700:oklch(50.5% .213 27.518);--color-green-500:oklch(72.3% .219 149.579);--color-green-600:oklch(62.7% .194 149.214);--color-green-700:oklch(52.7% .154 150.069);--color-blue-50:oklch(97% .014 254.604);--color-blue-100:oklch(93.2% .032 255.585);--color-blue-200:oklch(88.2% .059 254.128);--color-blue-500:oklch(62.3% .214 259.815);--color-blue-600:oklch(54.6% .245 262.881);--color-blue-700:oklch(48.8% .243 264.376);--color-blue-800:oklch(42.4% .199 265.638);--color-purple-500:oklch(62.7% .265 303.9);--color-purple-600:oklch(55.8% .288 302.321);--color-gray-50:oklch(98.5% .002 247.839);--color-gray-100:oklch(96.7% .003 264.542);--color-gray-200:oklch(92.8% .006 264.531);--color-gray-300:oklch(87.2% .01 258.338);--color-gray-400:oklch(70.7% .022 261.325);--color-gray-500:oklch(55.1% .027 264.364);--color-gray-600:oklch(44.6% .03 256.802);--color-gray-700:oklch(37.3% .034 259.733);--color-gray-800:oklch(27.8% .033 256.848);--color-gray-900:oklch(21% .034 264.665);--color-white:#fff;--spacing:.25rem;--container-3xl:48rem;--container-5xl:64rem;--container-6xl:72rem;--text-xs:.75rem;--text-xs--line-height:calc(1/.75);--text-sm:.875rem;--text-sm--line-height:calc(1.25/.875);--text-base:1rem;--text-base--line-height:calc(1.5/1);--text-lg:1.125rem;--text-lg--line-height:calc(1.75/1.125);--text-xl:1.25rem;--text-xl--line-height:calc(1.75/1.25);--text-2xl:1.5rem;--text-2xl--line-height:calc(2/1.5);--text-3xl:1.875rem;--text-3xl--line-height:calc(2.25/1.875);--text-4xl:2.25rem;--text-4xl--line-height:calc(2.5/2.25);--font-weight-medium:500;--font-weight-semibold:600;--font-weight-bold:700;--font-weight-extrabold:800;--radius-md:.375rem;--radius-lg:.5rem;--default-transition-duration:.15s;--default-transition-timing-function:cubic-bezier(.4,0,.2,1);--default-font-family:var(--font-sans);--default-mono-font-family:var(--font-mono)}}@layer base{*,:after,:before,::backdrop{box-sizing:border-box;border:0 solid;margin:0;padding:0}::file-selector-button{box-sizing:border-box;border:0 solid;margin:0;padding:0}html,:host{-webkit-text-size-adjust:100%;tab-size:4;line-height:1.5;font-family:var(--default-font-family,ui-sans-serif,system-ui,sans-serif,"Apple Color Emoji","Segoe UI Emoji","Segoe UI Symbol","Noto Color Emoji");font-feature-settings:var(--default-font-feature-settings,normal);font-variation-settings:var(--default-font-variation-settings,normal);-webkit-tap-highlight-color:transparent}hr{height:0;color:inherit;border-top-width:1px}abbr:where([title]){-webkit-text-decoration:underline dotted;text-decoration:underline dotted}h1,h2,h3,h4,h5,h6{font-size:inherit;font-weight:inherit}a{color:inherit;-webkit-text-decoration:inherit;-webkit-text-decoration:inherit;-webkit-text-decoration:inherit;text-decoration:inherit}b,strong{font-weight:bolder}code,kbd,samp,pre{font-family:var(--default-mono-font-family,ui-monospace,SFMono-Regular,Menlo,Monaco,Consolas,"Liberation Mono","Courier New",monospace);font-feature-settings:var(--default-mono-font-feature-settings,normal);font-variation-settings:var(--default-mono-font-variation-settings,normal);font-size:1em}small{font-size:80%}sub,sup{vertical-align:baseline;font-size:75%;line-height:0;position:relative}sub{bottom:-.25em}sup{top:-.5em}table{text-indent:0;border-color:inherit;border-collapse:collapse}:-moz-focusring{outline:auto}progress{vertical-align:baseline}summary{display:list-item}ol,ul,menu{list-style:none}img,svg,video,canvas,audio,iframe,embed,object{vertical-align:middle;display:block}img,video{max-width:100%;height:auto}button,input,select,optgroup,textarea{font:inherit;font-feature-settings:inherit;font-variation-settings:inherit;letter-spacing:inherit;color:inherit;opacity:1;background-color:#0000;border-radius:0}::file-selector-button{font:inherit;font-feature-settings:inherit;font-variation-settings:inherit;letter-spacing:inherit;color:inherit;opacity:1;background-color:#0000;border-radius:0}:where(select:is([multiple],[size])) optgroup{font-weight:bolder}:where(select:is([multiple],[size])) optgroup option{padding-inline-start:20px}::file-selector-button{margin-inline-end:4px}::placeholder{opacity:1}@supports (not ((-webkit-appearance:-apple-pay-button))) or (contain-intrinsic-size:1px){::placeholder{color:currentColor}@supports (color:color-mix(in lab, red, red)){::placeholder{color:color-mix(in oklab,currentcolor 50%,transparent)}}}textarea{resize:vertical}::-webkit-search-decoration{-webkit-appearance:none}::-webkit-date-and-time-value{min-height:1lh;text-align:inherit}::-webkit-datetime-edit{display:inline-flex}::-webkit-datetime-edit-fields-wrapper{padding:0}::-webkit-datetime-edit{padding-block:0}::-webkit-datetime-edit-year-field{padding-block:0}::-webkit-datetime-edit-month-field{padding-block:0}::-webkit-datetime-edit-day-field{padding-block:0}::-webkit-datetime-edit-hour-field{padding-block:0}::-webkit-datetime-edit-minute-field{padding-block:0}::-webkit-datetime-edit-second-field{padding-block:0}::-webkit-datetime-edit-millisecond-field{padding-block:0}::-webkit-datetime-edit-meridiem-field{padding-block:0}::-webkit-calendar-picker-indicator{line-height:1}:-moz-ui-invalid{box-shadow:none}button,input:where([type=button],[type=reset],[type=submit]){appearance:button}::file-selector-button{appearance:button}::-webkit-inner-spin-button{height:auto}::-webkit-outer-spin-button{height:auto}[hidden]:where(:not([hidden=until-found])){display:none!important}}@layer components;@layer utilities{.visible{visibility:visible}.sr-only{clip-path:inset(50%);white-space:nowrap;border-width:0;width:1px;height:1px;margin:-1px;padding:0;position:absolute;overflow:hidden}.absolute{position:absolute}.relative{position:relative}.static{position:static}.top-0{top:calc(var(--spacing)*0)}.bottom-0{bottom:calc(var(--spacing)*0)}.left-1{left:calc(var(--spacing)*1)}.left-1\/2{left:50%}.float-left{float:left}.float-right{float:right}.container{width:100%}@media (min-width:40rem){.container{max-width:40rem}}@media (min-width:48rem){.container{max-width:48rem}}@media (min-width:64rem){.container{max-width:64rem}}@media (min-width:80rem){.container{max-width:80rem}}@media (min-width:96rem){.container{max-width:96rem}}.mx-2{margin-inline:calc(var(--spacing)*2)}.mx-8{margin-inline:calc(var(--spacing)*8)}.mx-auto{margin-inline:auto}.my-16{margin-block:calc(var(--spacing)*16)}.mt-1{margin-top:calc(var(--spacing)*1)}.mt-2{margin-top:calc(var(--spacing)*2)}.mt-4{margin-top:calc(var(--spacing)*4)}.mt-8{margin-top:calc(var(--spacing)*8)}.mb-1{margin-bottom:calc(var(--spacing)*1)}.mb-2{margin-bottom:calc(var(--spacing)*2)}.mb-3{margin-bottom:calc(var(--spacing)*3)}.mb-4{margin-bottom:calc(var(--spacing)*4)}.mb-6{margin-bottom:calc(var(--spacing)*6)}.mb-8{margin-bottom:calc(var(--spacing)*8)}.ml-2{margin-left:calc(var(--spacing)*2)}.ml-4{margin-left:calc(var(--spacing)*4)}.ml-auto{margin-left:auto}.block{display:block}.flex{display:flex}.grid{display:grid}.inline{display:inline}.inline-block{display:inline-block}.inline-flex{display:inline-flex}.table{display:table}.h-4{height:calc(var(--spacing)*4)}.h-8{height:calc(var(--spacing)*8)}.h-12{height:calc(var(--spacing)*12)}.h-24{height:calc(var(--spacing)*24)}.h-32{height:calc(var(--spacing)*32)}.h-full{height:100%}.h-screen{height:100vh}.w-1{width:calc(var(--spacing)*1)}.w-1\/2{width:50%}.w-4{width:calc(var(--spacing)*4)}.w-8{width:calc(var(--spacing)*8)}.w-20{width:calc(var(--spacing)*20)}.w-24{width:calc(var(--spacing)*24)}.w-64{width:calc(var(--spacing)*64)}.w-\[1px\]{width:1px}.w-full{width:100%}.max-w-3xl{max-width:var(--container-3xl)}.max-w-5xl{max-width:var(--container-5xl)}.max-w-6xl{max-width:var(--container-6xl)}.flex-1{flex:1}.flex-grow{flex-grow:1}.border-collapse{border-collapse:collapse}.cursor-pointer{cursor:pointer}.grid-cols-1{grid-template-columns:repeat(1,minmax(0,1fr))}.grid-cols-2{grid-template-columns:repeat(2,minmax(0,1fr))}.flex-col{flex-direction:column}.flex-wrap{flex-wrap:wrap}.items-center{align-items:center}.justify-between{justify-content:space-between}.justify-center{justify-content:center}.justify-end{justify-content:flex-end}.gap-1{gap:calc(var(--spacing)*1)}.gap-2{gap:calc(var(--spacing)*2)}.gap-3{gap:calc(var(--spacing)*3)}.gap-4{gap:calc(var(--spacing)*4)}.gap-5{gap:calc(var(--spacing)*5)}.gap-6{gap:calc(var(--spacing)*6)}:where(.space-y-4>:not(:last-child)){--tw-space-y-reverse:0;margin-block-start:calc(calc(var(--spacing)*4)*var(--tw-space-y-reverse));margin-block-end:calc(calc(var(--spacing)*4)*calc(1 - var(--tw-space-y-reverse)))}:where(.space-y-6>:not(:last-child)){--tw-space-y-reverse:0;margin-block-start:calc(calc(var(--spacing)*6)*var(--tw-space-y-reverse));margin-block-end:calc(calc(var(--spacing)*6)*calc(1 - var(--tw-space-y-reverse)))}:where(.space-x-2>:not(:last-child)){--tw-space-x-reverse:0;margin-inline-start:calc(calc(var(--spacing)*2)*var(--tw-space-x-reverse));margin-inline-end:calc(calc(var(--spacing)*2)*calc(1 - var(--tw-space-x-reverse)))}.truncate{text-overflow:ellipsis;white-space:nowrap;overflow:hidden}.overflow-hidden{overflow:hidden}.rounded{border-radius:.25rem}.rounded-full{border-radius:3.40282e38px}.rounded-lg{border-radius:var(--radius-lg)}.rounded-md{border-radius:var(--radius-md)}.border{border-style:var(--tw-border-style);border-width:1px}.border-0{border-style:var(--tw-border-style);border-width:0}.border-2{border-style:var(--tw-border-style);border-width:2px}.border-t{border-top-style:var(--tw-border-style);border-top-width:1px}.border-b{border-bottom-style:var(--tw-border-style);border-bottom-width:1px}.border-gray-200{border-color:var(--color-gray-200)}.border-gray-300{border-color:var(--color-gray-300)}.border-gray-400{border-color:var(--color-gray-400)}.border-gray-500{border-color:var(--color-gray-500)}.border-gray-600{border-color:var(--color-gray-600)}.bg-blue-100{background-color:var(--color-blue-100)}.bg-blue-500{background-color:var(--color-blue-500)}.bg-gray-100{background-color:var(--color-gray-100)}.bg-gray-200{background-color:var(--color-gray-200)}.bg-gray-300{background-color:var(--color-gray-300)}.bg-gray-400{background-color:var(--color-gray-400)}.bg-gray-500{background-color:var(--color-gray-500)}.bg-gray-700{background-color:var(--color-gray-700)}.bg-green-500{background-color:var(--color-green-500)}.bg-purple-500{background-color:var(--color-purple-500)}.bg-red-500{background-color:var(--color-red-500)}.bg-white{background-color:var(--color-white)}.object-cover{object-fit:cover}.p-2{padding:calc(var(--spacing)*2)}.p-3{padding:calc(var(--spacing)*3)}.p-4{padding:calc(var(--spacing)*4)}.p-6{padding:calc(var(--spacing)*6)}.px-2{padding-inline:calc(var(--spacing)*2)}.px-2\.5{padding-inline:calc(var(--spacing)*2.5)}.px-3{padding-inline:calc(var(--spacing)*3)}.px-4{padding-inline:calc(var(--spacing)*4)}.px-6{padding-inline:calc(var(--spacing)*6)}.py-0{padding-block:calc(var(--spacing)*0)}.py-0\.5{padding-block:calc(var(--spacing)*.5)}.py-1{padding-block:calc(var(--spacing)*1)}.py-2{padding-block:calc(var(--spacing)*2)}.py-4{padding-block:calc(var(--spacing)*4)}.py-8{padding-block:calc(var(--spacing)*8)}.py-10{padding-block:calc(var(--spacing)*10)}.pr-5{padding-right:calc(var(--spacing)*5)}.pb-2{padding-bottom:calc(var(--spacing)*2)}.pb-3{padding-bottom:calc(var(--spacing)*3)}.pb-4{padding-bottom:calc(var(--spacing)*4)}.pl-5{padding-left:calc(var(--spacing)*5)}.text-center{text-align:center}.text-right{text-align:right}.text-2xl{font-size:var(--text-2xl);line-height:var(--tw-leading,var(--text-2xl--line-height))}.text-3xl{font-size:var(--text-3xl);line-height:var(--tw-leading,var(--text-3xl--line-height))}.text-4xl{font-size:var(--text-4xl);line-height:var(--tw-leading,var(--text-4xl--line-height))}.text-base{font-size:var(--text-base);line-height:var(--tw-leading,var(--text-base--line-height))}.text-lg{font-size:var(--text-lg);line-height:var(--tw-leading,var(--text-lg--line-height))}.text-sm{font-size:var(--text-sm);line-height:var(--tw-leading,var(--text-sm--line-height))}.text-xl{font-size:var(--text-xl);line-height:var(--tw-leading,var(--text-xl--line-height))}.text-xs{font-size:var(--text-xs);line-height:var(--tw-leading,var(--text-xs--line-height))}.font-bold{--tw-font-weight:var(--font-weight-bold);font-weight:var(--font-weight-bold)}.font-extrabold{--tw-font-weight:var(--font-weight-extrabold);font-weight:var(--font-weight-extrabold)}.font-medium{--tw-font-weight:var(--font-weight-medium);font-weight:var(--font-weight-medium)}.font-semibold{--tw-font-weight:var(--font-weight-semibold);font-weight:var(--font-weight-semibold)}.text-blue-500{color:var(--color-blue-500)}.text-blue-800{color:var(--color-blue-800)}.text-gray-400{color:var(--color-gray-400)}.text-gray-500{color:var(--color-gray-500)}.text-gray-600{color:var(--color-gray-600)}.text-gray-700{color:var(--color-gray-700)}.text-gray-900{color:var(--color-gray-900)}.text-green-700{color:var(--color-green-700)}.text-red-500{color:var(--color-red-500)}.text-red-700{color:var(--color-red-700)}.text-white{color:var(--color-white)}.italic{font-style:italic}.underline{text-decoration-line:underline}.placeholder-gray-400::placeholder{color:var(--color-gray-400)}.shadow-sm{--tw-shadow:0 1px 3px 0 var(--tw-shadow-color,#0000001a),0 1px 2px -1px var(--tw-shadow-color,#0000001a);box-shadow:var(--tw-inset-shadow),var(--tw-inset-ring-shadow),var(--tw-ring-offset-shadow),var(--tw-ring-shadow),var(--tw-shadow)}.outline{outline-style:var(--tw-outline-style);outline-width:1px}.filter{filter:var(--tw-blur,)var(--tw-brightness,)var(--tw-contrast,)var(--tw-grayscale,)var(--tw-hue-rotate,)var(--tw-invert,)var(--tw-saturate,)var(--tw-sepia,)var(--tw-drop-shadow,)}.transition{transition-property:color,background-color,border-color,outline-color,text-decoration-color,fill,stroke,--tw-gradient-from,--tw-gradient-via,--tw-gradient-to,opacity,box-shadow,transform,translate,scale,rotate,filter,-webkit-backdrop-filter,backdrop-filter,display,content-visibility,overlay,pointer-events;transition-timing-function:var(--tw-ease,var(--default-transition-timing-function));transition-duration:var(--tw-duration,var(--default-transition-duration))}.transition-colors{transition-property:color,background-color,border-color,outline-color,text-decoration-color,fill,stroke,--tw-gradient-from,--tw-gradient-via,--tw-gradient-to;transition-timing-function:var(--tw-ease,var(--default-transition-timing-function));transition-duration:var(--tw-duration,var(--default-transition-duration))}.file\:mr-4::file-selector-button{margin-right:calc(var(--spacing)*4)}.file\:rounded::file-selector-button{border-radius:.25rem}.file\:border-0::file-selector-button{border-style:var(--tw-border-style);border-width:0}.file\:bg-blue-50::file-selector-button{background-color:var(--color-blue-50)}.file\:px-4::file-selector-button{padding-inline:calc(var(--spacing)*4)}.file\:py-2::file-selector-button{padding-block:calc(var(--spacing)*2)}.file\:text-sm::file-selector-button{font-size:var(--text-sm);line-height:var(--tw-leading,var(--text-sm--line-height))}.file\:font-semibold::file-selector-button{--tw-font-weight:var(--font-weight-semibold);font-weight:var(--font-weight-semibold)}.file\:text-blue-700::file-selector-button{color:var(--color-blue-700)}@media (hover:hover){.hover\:overflow-y-auto:hover{overflow-y:auto}.hover\:bg-blue-200:hover{background-color:var(--color-blue-200)}.hover\:bg-blue-600:hover{background-color:var(--color-blue-600)}.hover\:bg-gray-50:hover{background-color:var(--color-gray-50)}.hover\:bg-gray-100:hover{background-color:var(--color-gray-100)}.hover\:bg-gray-200:hover{background-color:var(--color-gray-200)}.hover\:bg-gray-500:hover{background-color:var(--color-gray-500)}.hover\:bg-gray-600:hover{background-color:var(--color-gray-600)}.hover\:bg-green-600:hover{background-color:var(--color-green-600)}.hover\:bg-red-600:hover{background-color:var(--color-red-600)}.hover\:text-blue-600:hover{color:var(--color-blue-600)}.hover\:text-gray-700:hover{color:var(--color-gray-700)}.hover\:text-gray-800:hover{color:var(--color-gray-800)}.hover\:text-gray-900:hover{color:var(--color-gray-900)}.hover\:file\:bg-blue-100:hover::file-selector-button{background-color:var(--color-blue-100)}}.focus\:border-\[1px\]:focus{border-style:var(--tw-border-style);border-width:1px}.focus\:border-gray-300:focus{border-color:var(--color-gray-300)}.focus\:border-gray-400:focus{border-color:var(--color-gray-400)}.focus\:ring-0:focus{--tw-ring-shadow:var(--tw-ring-inset,)0 0 0 calc(0px + var(--tw-ring-offset-width))var(--tw-ring-color,currentcolor);box-shadow:var(--tw-inset-shadow),var(--tw-inset-ring-shadow),var(--tw-ring-offset-shadow),var(--tw-ring-shadow),var(--tw-shadow)}.focus\:ring-1:focus{--tw-ring-shadow:var(--tw-ring-inset,)0 0 0 calc(1px + var(--tw-ring-offset-width))var(--tw-ring-color,currentcolor);box-shadow:var(--tw-inset-shadow),var(--tw-inset-ring-shadow),var(--tw-ring-offset-shadow),var(--tw-ring-shadow),var(--tw-shadow)}.focus\:ring-blue-500:focus{--tw-ring-color:var(--color-blue-500)}.focus\:ring-gray-400:focus{--tw-ring-color:var(--color-gray-400)}.focus\:outline-none:focus{--tw-outline-style:none;outline-style:none}@media (min-width:48rem){.md\:grid-cols-3{grid-template-columns:repeat(3,minmax(0,1fr))}.md\:grid-cols-4{grid-template-columns:repeat(4,minmax(0,1fr))}}}.layout-switcher.mode-split .text-area,.layout-switcher.mode-split .preview-area{flex:1;display:block}.layout-switcher.mode-split .original-preview-area{display:none}.layout-switcher.mode-text-only .text-area{flex:1;display:block}.layout-switcher.mode-text-only .preview-area,.layout-switcher.mode-text-only .original-preview-area,.layout-switcher.mode-text-only .layout-divider,.layout-switcher.mode-preview-only .text-area{display:none}.layout-switcher.mode-preview-only .preview-area{flex:1;display:block}.layout-switcher.mode-preview-only .original-preview-area,.layout-switcher.mode-preview-only .layout-divider{display:none}.layout-switcher.mode-original-preview .text-area{flex:1;display:block}.layout-switcher.mode-original-preview .preview-area{display:none}.layout-switcher.mode-original-preview .original-preview-area{flex:1;display:block}.layout-switcher.mode-original-preview .layout-divider{display:block}.layout-buttons button{cursor:pointer;background:#fff;border:1px solid #ccc;border-radius:4px;min-width:32px;height:32px;padding:4px 8px;font-size:16px}.layout-buttons button:hover{background:#f3f4f6}.layout-buttons button.active{background:#e5e7eb;border-color:#6b7280}.layout-switcher{width:100%;height:100%}.blue-theme .blog-title{color:var(--color-blue-600)}.blue-theme .theme-accent{background-color:var(--color-blue-500);color:var(--color-white)}.green-theme .blog-title{color:var(--color-green-600)}.green-theme .theme-accent{background-color:var(--color-green-500);color:var(--color-white)}.purple-theme .blog-title{color:var(--color-purple-600)}.purple-theme .theme-accent{background-color:var(--color-purple-500);color:var(--color-white)}.gray-theme .blog-title{color:var(--color-gray-600)}.gray-theme .theme-accent{background-color:var(--color-gray-500);color:var(--color-white)}[data-markdown-preview-target=preview] img{object-fit:contain;border-radius:4px;width:100%;height:auto;margin:10px 0}.article-content img{object-fit:contain;object-fit:contain;border-radius:4px;max-width:100%;height:auto;max-height:500px;margin:15px auto;display:block;box-shadow:0 2px 8px #0000001a}.tab-container{margin:20px 0}.tab-buttons{border-bottom:2px solid #ddd;margin-bottom:20px;display:flex}.tab-button{cursor:pointer;background:#f5f5f5;border:none;border-top:2px solid #0000;margin-right:2px;padding:10px 20px}.tab-button.active{background:#fff;border-top-color:#007bff;font-weight:700}.tab-content{display:none}.tab-content.active{display:block}@property --tw-space-y-reverse{syntax:"*";inherits:false;initial-value:0}@property --tw-space-x-reverse{syntax:"*";inherits:false;initial-value:0}@property --tw-border-style{syntax:"*";inherits:false;initial-value:solid}@property --tw-font-weight{syntax:"*";inherits:false}@property --tw-shadow{syntax:"*";inherits:false;initial-value:0 0 #0000}@property --tw-shadow-color{syntax:"*";inherits:false}@property --tw-shadow-alpha{syntax:"<percentage>";inherits:false;initial-value:100%}@property --tw-inset-shadow{syntax:"*";inherits:false;initial-value:0 0 #0000}@property --tw-inset-shadow-color{syntax:"*";inherits:false}@property --tw-inset-shadow-alpha{syntax:"<percentage>";inherits:false;initial-value:100%}@property --tw-ring-color{syntax:"*";inherits:false}@property --tw-ring-shadow{syntax:"*";inherits:false;initial-value:0 0 #0000}@property --tw-inset-ring-color{syntax:"*";inherits:false}@property --tw-inset-ring-shadow{syntax:"*";inherits:false;initial-value:0 0 #0000}@property --tw-ring-inset{syntax:"*";inherits:false}@property --tw-ring-offset-width{syntax:"<length>";inherits:false;initial-value:0}@property --tw-ring-offset-color{syntax:"*";inherits:false;initial-value:#fff}@property --tw-ring-offset-shadow{syntax:"*";inherits:false;initial-value:0 0 #0000}@property --tw-outline-style{syntax:"*";inherits:false;initial-value:solid}@property --tw-blur{syntax:"*";inherits:false}@property --tw-brightness{syntax:"*";inherits:false}@property --tw-contrast{syntax:"*";inherits:false}@property --tw-grayscale{syntax:"*";inherits:false}@property --tw-hue-rotate{syntax:"*";inherits:false}@property --tw-invert{syntax:"*";inherits:false}@property --tw-opacity{syntax:"*";inherits:false}@property --tw-saturate{syntax:"*";inherits:false}@property --tw-sepia{syntax:"*";inherits:false}@property --tw-drop-shadow{syntax:"*";inherits:false}@property --tw-drop-shadow-color{syntax:"*";inherits:false}@property --tw-drop-shadow-alpha{syntax:"<percentage>";inherits:false;initial-value:100%}@property --tw-drop-shadow-size{syntax:"*";inherits:false}```

## File: `app/assets/stylesheets/application.css`

```
.flash-message {
  transition: opacity 0.3s ease-out;
}
```

## File: `app/assets/stylesheets/github-markdown.css`

```
```

## File: `app/assets/stylesheets/layout_switcher.css`

```
.layout-switcher.mode-split .text-area {
  flex: 1;
  display: block;
}

.layout-switcher.mode-split .preview-area {
  flex: 1;
  display: block;
}

.layout-switcher.mode-split .original-preview-area {
  display: none;
}

.layout-switcher.mode-text-only .text-area {
  flex: 1;
  display: block;
}

.layout-switcher.mode-text-only .preview-area {
  display: none;
}

.layout-switcher.mode-text-only .original-preview-area {
  display: none;
}

.layout-switcher.mode-text-only .layout-divider {
  display: none;
}

.layout-switcher.mode-preview-only .text-area {
  display: none;
}

.layout-switcher.mode-preview-only .preview-area {
  flex: 1;
  display: block;
}

.layout-switcher.mode-preview-only .original-preview-area {
  display: none;
}

.layout-switcher.mode-preview-only .layout-divider {
  display: none;
}

.layout-switcher.mode-original-preview .text-area {
  flex: 1;
  display: block;
}

.layout-switcher.mode-original-preview .preview-area {
  display: none;
}

.layout-switcher.mode-original-preview .original-preview-area {
  flex: 1;
  display: block;
}

.layout-switcher.mode-original-preview .layout-divider {
  display: block;
}

/* ボタンスタイル */
.layout-buttons button {
  padding: 4px 8px;
  border: 1px solid #ccc;
  background: white;
  cursor: pointer;
  font-size: 16px;
  min-width: 32px;
  height: 32px;
  border-radius: 4px;
}

.layout-buttons button:hover {
  background: #f3f4f6;
}

.layout-buttons button.active {
  background: #e5e7eb;
  border-color: #6b7280;
}

/* レイアウトの基本スタイル */
.layout-switcher {
  width: 100%;
  height: 100%;
}
```

## File: `app/assets/stylesheets/markdown-body.css`

```
.markdown-container {
  all: revert;
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
}

.markdown-container * {
  all: revert;
}

.markdown-body {
  -ms-text-size-adjust: 100%;
  -webkit-text-size-adjust: 100%;
  margin: 0;
  color: #1f2328;
  background-color: #fff;
  font-family:
    -apple-system, BlinkMacSystemFont, "Segoe UI", "Noto Sans", Helvetica,
    Arial, sans-serif, "Apple Color Emoji", "Segoe UI Emoji";
  font-size: 16px;
  line-height: 1.5;
  word-wrap: break-word;
}
.markdown-body .octicon {
  display: inline-block;
  fill: currentColor;
  vertical-align: text-bottom;
}
.markdown-body h1:hover .anchor .octicon-link:before,
.markdown-body h2:hover .anchor .octicon-link:before,
.markdown-body h3:hover .anchor .octicon-link:before,
.markdown-body h4:hover .anchor .octicon-link:before,
.markdown-body h5:hover .anchor .octicon-link:before,
.markdown-body h6:hover .anchor .octicon-link:before {
  width: 16px;
  height: 16px;
  content: " ";
  display: inline-block;
  background-color: currentColor;
  -webkit-mask-image: url("data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16' version='1.1' aria-hidden='true'><path fill-rule='evenodd' d='M7.775 3.275a.75.75 0 001.06 1.06l1.25-1.25a2 2 0 112.83 2.83l-2.5 2.5a2 2 0 01-2.83 0 .75.75 0 00-1.06 1.06 3.5 3.5 0 004.95 0l2.5-2.5a3.5 3.5 0 00-4.95-4.95l-1.25 1.25zm-4.69 9.64a2 2 0 010-2.83l2.5-2.5a2 2 0 012.83 0 .75.75 0 001.06-1.06 3.5 3.5 0 00-4.95 0l-2.5 2.5a3.5 3.5 0 004.95 4.95l1.25-1.25a.75.75 0 00-1.06-1.06l-1.25 1.25a2 2 0 01-2.83 0z'></path></svg>");
  mask-image: url("data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16' version='1.1' aria-hidden='true'><path fill-rule='evenodd' d='M7.775 3.275a.75.75 0 001.06 1.06l1.25-1.25a2 2 0 112.83 2.83l-2.5 2.5a2 2 0 01-2.83 0 .75.75 0 00-1.06 1.06 3.5 3.5 0 004.95 0l2.5-2.5a3.5 3.5 0 00-4.95-4.95l-1.25 1.25zm-4.69 9.64a2 2 0 010-2.83l2.5-2.5a2 2 0 012.83 0 .75.75 0 001.06-1.06 3.5 3.5 0 00-4.95 0l-2.5 2.5a3.5 3.5 0 004.95 4.95l1.25-1.25a.75.75 0 00-1.06-1.06l-1.25 1.25a2 2 0 01-2.83 0z'></path></svg>");
}
.markdown-body details,
.markdown-body figcaption,
.markdown-body figure {
  display: block;
}
.markdown-body summary {
  display: list-item;
}
.markdown-body [hidden] {
  display: none !important;
}
.markdown-body a {
  background-color: transparent;
  color: #0969da;
  text-decoration: none;
}
.markdown-body abbr[title] {
  border-bottom: none;
  -webkit-text-decoration: underline dotted;
  text-decoration: underline dotted;
}
.markdown-body b,
.markdown-body strong {
  font-weight: 600;
}
.markdown-body dfn {
  font-style: italic;
}
.markdown-body h1 {
  margin: 0.67em 0;
  font-weight: 600;
  padding-bottom: 0.3em;
  font-size: 2em;
  border-bottom: 1px solid #d7dde3;
}
.markdown-body mark {
  background-color: #fff8c5;
  color: #1f2328;
}
.markdown-body small {
  font-size: 90%;
}
.markdown-body sub,
.markdown-body sup {
  font-size: 75%;
  line-height: 0;
  position: relative;
  vertical-align: baseline;
}
.markdown-body sub {
  bottom: -0.25em;
}
.markdown-body sup {
  top: -0.5em;
}
.markdown-body img {
  border-style: none;
  max-width: 100%;
  box-sizing: content-box;
  background-color: #fff;
}
.markdown-body code,
.markdown-body kbd,
.markdown-body pre,
.markdown-body samp {
  font-family: monospace;
  font-size: 1em;
}
.markdown-body figure {
  margin: 1em 40px;
}
.markdown-body hr {
  box-sizing: content-box;
  overflow: hidden;
  background: 0 0;
  border-bottom: 1px solid #d7dde3;
  height: 0.25em;
  padding: 0;
  margin: 24px 0;
  background-color: #d0d7de;
  border: 0;
}
.markdown-body input {
  font: inherit;
  margin: 0;
  overflow: visible;
  font-family: inherit;
  font-size: inherit;
  line-height: inherit;
}
.markdown-body [type="button"],
.markdown-body [type="reset"],
.markdown-body [type="submit"] {
  -webkit-appearance: button;
}
.markdown-body [type="checkbox"],
.markdown-body [type="radio"] {
  box-sizing: border-box;
  padding: 0;
}
.markdown-body [type="number"]::-webkit-inner-spin-button,
.markdown-body [type="number"]::-webkit-outer-spin-button {
  height: auto;
}
.markdown-body [type="search"]::-webkit-search-cancel-button,
.markdown-body [type="search"]::-webkit-search-decoration {
  -webkit-appearance: none;
}
.markdown-body ::-webkit-input-placeholder {
  color: inherit;
  opacity: 0.54;
}
.markdown-body ::-webkit-file-upload-button {
  -webkit-appearance: button;
  font: inherit;
}
.markdown-body a:hover {
  text-decoration: underline;
}
.markdown-body ::placeholder {
  color: #6e7781;
  opacity: 1;
}
.markdown-body hr::before {
  display: table;
  content: "";
}
.markdown-body hr::after {
  display: table;
  clear: both;
  content: "";
}
.markdown-body table {
  border-spacing: 0;
  border-collapse: collapse;
  display: block;
  width: max-content;
  max-width: 100%;
  overflow: auto;
}
.markdown-body td,
.markdown-body th {
  padding: 0;
}
.markdown-body details summary {
  cursor: pointer;
}
.markdown-body details:not([open]) > :not(summary) {
  display: none !important;
}
.markdown-body [role="button"]:focus,
.markdown-body a:focus,
.markdown-body input[type="checkbox"]:focus,
.markdown-body input[type="radio"]:focus {
  outline: 2px solid #0969da;
  outline-offset: -2px;
  box-shadow: none;
}
.markdown-body [role="button"]:focus:not(:focus-visible),
.markdown-body a:focus:not(:focus-visible),
.markdown-body input[type="checkbox"]:focus:not(:focus-visible),
.markdown-body input[type="radio"]:focus:not(:focus-visible) {
  outline: solid 1px transparent;
}
.markdown-body [role="button"]:focus-visible,
.markdown-body a:focus-visible,
.markdown-body input[type="checkbox"]:focus-visible,
.markdown-body input[type="radio"]:focus-visible {
  outline: 2px solid #0969da;
  outline-offset: -2px;
  box-shadow: none;
}
.markdown-body a:not([class]):focus,
.markdown-body a:not([class]):focus-visible,
.markdown-body input[type="checkbox"]:focus,
.markdown-body input[type="checkbox"]:focus-visible,
.markdown-body input[type="radio"]:focus,
.markdown-body input[type="radio"]:focus-visible {
  outline-offset: 0;
}
.markdown-body kbd {
  display: inline-block;
  padding: 3px 5px;
  font:
    11px ui-monospace,
    SFMono-Regular,
    SF Mono,
    Menlo,
    Consolas,
    Liberation Mono,
    monospace;
  line-height: 10px;
  color: #1f2328;
  vertical-align: middle;
  background-color: #f6f8fa;
  border: solid 1px rgba(175, 184, 193, 0.2);
  border-bottom-color: rgba(175, 184, 193, 0.2);
  border-radius: 6px;
  box-shadow: inset 0 -1px 0 rgba(175, 184, 193, 0.2);
}
.markdown-body h1,
.markdown-body h2,
.markdown-body h3,
.markdown-body h4,
.markdown-body h5,
.markdown-body h6 {
  margin-top: 24px;
  margin-bottom: 16px;
  font-weight: 600;
  line-height: 1.25;
}
.markdown-body h2 {
  font-weight: 600;
  padding-bottom: 0.3em;
  font-size: 1.5em;
  border-bottom: 1px solid #d7dde3;
}
.markdown-body h3 {
  font-weight: 600;
  font-size: 1.25em;
}
.markdown-body h4 {
  font-weight: 600;
  font-size: 1em;
}
.markdown-body h5 {
  font-weight: 600;
  font-size: 0.875em;
}
.markdown-body h6 {
  font-weight: 600;
  font-size: 0.85em;
  color: #656d76;
}
.markdown-body p {
  margin-top: 0;
  margin-bottom: 10px;
}
.markdown-body blockquote {
  margin: 0;
  padding: 0 1em;
  color: #656d76;
  border-left: 0.25em solid #d0d7de;
}
.markdown-body ol,
.markdown-body ul {
  margin-top: 0;
  margin-bottom: 0;
  padding-left: 2em;
}
.markdown-body ol ol,
.markdown-body ul ol {
  list-style-type: lower-roman;
}
.markdown-body ol ol ol,
.markdown-body ol ul ol,
.markdown-body ul ol ol,
.markdown-body ul ul ol {
  list-style-type: lower-alpha;
}
.markdown-body dd {
  margin-left: 0;
}
.markdown-body code,
.markdown-body samp,
.markdown-body tt {
  font-family:
    ui-monospace,
    SFMono-Regular,
    SF Mono,
    Menlo,
    Consolas,
    Liberation Mono,
    monospace;
  font-size: 12px;
}
.markdown-body pre {
  margin-top: 0;
  margin-bottom: 0;
  font-family:
    ui-monospace,
    SFMono-Regular,
    SF Mono,
    Menlo,
    Consolas,
    Liberation Mono,
    monospace;
  font-size: 12px;
  word-wrap: normal;
}
.markdown-body .octicon {
  display: inline-block;
  overflow: visible !important;
  vertical-align: text-bottom;
  fill: currentColor;
}
.markdown-body input::-webkit-inner-spin-button,
.markdown-body input::-webkit-outer-spin-button {
  margin: 0;
  -webkit-appearance: none;
  appearance: none;
}
.markdown-body .color-fg-accent {
  color: #0969da !important;
}
.markdown-body .color-fg-attention {
  color: #9a6700 !important;
}
.markdown-body .color-fg-done {
  color: #8250df !important;
}
.markdown-body .flex-items-center {
  align-items: center !important;
}
.markdown-body .mb-1 {
  margin-bottom: var(--base-size-4, 4px) !important;
}
.markdown-body .text-semibold {
  font-weight: var(--base-text-weight-medium, 500) !important;
}
.markdown-body .d-inline-flex {
  display: inline-flex !important;
}
.markdown-body::before {
  display: table;
  content: "";
}
.markdown-body::after {
  display: table;
  clear: both;
  content: "";
}
.markdown-body > :first-child {
  margin-top: 0 !important;
}
.markdown-body > :last-child {
  margin-bottom: 0 !important;
}
.markdown-body a:not([href]) {
  color: inherit;
  text-decoration: none;
}
.markdown-body .absent {
  color: #d1242f;
}
.markdown-body .anchor {
  float: left;
  padding-right: 4px;
  margin-left: -20px;
  line-height: 1;
}
.markdown-body .anchor:focus {
  outline: 0;
}
.markdown-body blockquote,
.markdown-body details,
.markdown-body dl,
.markdown-body ol,
.markdown-body p,
.markdown-body pre,
.markdown-body table,
.markdown-body ul {
  margin-top: 0;
  margin-bottom: 16px;
}
.markdown-body blockquote > :first-child {
  margin-top: 0;
}
.markdown-body blockquote > :last-child {
  margin-bottom: 0;
}
.markdown-body h1 .octicon-link,
.markdown-body h2 .octicon-link,
.markdown-body h3 .octicon-link,
.markdown-body h4 .octicon-link,
.markdown-body h5 .octicon-link,
.markdown-body h6 .octicon-link {
  color: #1f2328;
  vertical-align: middle;
  visibility: hidden;
}
.markdown-body h1:hover .anchor,
.markdown-body h2:hover .anchor,
.markdown-body h3:hover .anchor,
.markdown-body h4:hover .anchor,
.markdown-body h5:hover .anchor,
.markdown-body h6:hover .anchor {
  text-decoration: none;
}
.markdown-body h1:hover .anchor .octicon-link,
.markdown-body h2:hover .anchor .octicon-link,
.markdown-body h3:hover .anchor .octicon-link,
.markdown-body h4:hover .anchor .octicon-link,
.markdown-body h5:hover .anchor .octicon-link,
.markdown-body h6:hover .anchor .octicon-link {
  visibility: visible;
}
.markdown-body h1 code,
.markdown-body h1 tt,
.markdown-body h2 code,
.markdown-body h2 tt,
.markdown-body h3 code,
.markdown-body h3 tt,
.markdown-body h4 code,
.markdown-body h4 tt,
.markdown-body h5 code,
.markdown-body h5 tt,
.markdown-body h6 code,
.markdown-body h6 tt {
  padding: 0 0.2em;
  font-size: inherit;
}
.markdown-body summary h1,
.markdown-body summary h2,
.markdown-body summary h3,
.markdown-body summary h4,
.markdown-body summary h5,
.markdown-body summary h6 {
  display: inline-block;
}
.markdown-body summary h1 .anchor,
.markdown-body summary h2 .anchor,
.markdown-body summary h3 .anchor,
.markdown-body summary h4 .anchor,
.markdown-body summary h5 .anchor,
.markdown-body summary h6 .anchor {
  margin-left: -40px;
}
.markdown-body summary h1,
.markdown-body summary h2 {
  padding-bottom: 0;
  border-bottom: 0;
}
.markdown-body ol.no-list,
.markdown-body ul.no-list {
  padding: 0;
  list-style-type: none;
}
.markdown-body ol[type="a s"] {
  list-style-type: lower-alpha;
}
.markdown-body ol[type="A s"] {
  list-style-type: upper-alpha;
}
.markdown-body ol[type="i s"] {
  list-style-type: lower-roman;
}
.markdown-body ol[type="I s"] {
  list-style-type: upper-roman;
}
.markdown-body ol[type="1"] {
  list-style-type: decimal;
}
.markdown-body div > ol:not([type]) {
  list-style-type: decimal;
}
.markdown-body ol ol,
.markdown-body ol ul,
.markdown-body ul ol,
.markdown-body ul ul {
  margin-top: 0;
  margin-bottom: 0;
}
.markdown-body li > p {
  margin-top: 16px;
}
.markdown-body li + li {
  margin-top: 0.25em;
}
.markdown-body dl {
  padding: 0;
}
.markdown-body dl dt {
  padding: 0;
  margin-top: 16px;
  font-size: 1em;
  font-style: italic;
  font-weight: 600;
}
.markdown-body dl dd {
  padding: 0 16px;
  margin-bottom: 16px;
}
.markdown-body table th {
  font-weight: 600;
}
.markdown-body table td,
.markdown-body table th {
  padding: 6px 13px;
  border: 1px solid #d0d7de;
}
.markdown-body table td > :last-child {
  margin-bottom: 0;
}
.markdown-body table tr {
  background-color: #fff;
  border-top: 1px solid #d7dde3;
}
.markdown-body table tr:nth-child(2n) {
  background-color: #f6f8fa;
}
.markdown-body table img {
  background-color: transparent;
}
.markdown-body img[align="right"] {
  padding-left: 20px;
}
.markdown-body img[align="left"] {
  padding-right: 20px;
}
.markdown-body .emoji {
  max-width: none;
  vertical-align: text-top;
  background-color: transparent;
}
.markdown-body span.frame {
  display: block;
  overflow: hidden;
}
.markdown-body span.frame > span {
  display: block;
  float: left;
  width: auto;
  padding: 7px;
  margin: 13px 0 0;
  overflow: hidden;
  border: 1px solid #d0d7de;
}
.markdown-body span.frame span img {
  display: block;
  float: left;
}
.markdown-body span.frame span span {
  display: block;
  padding: 5px 0 0;
  clear: both;
  color: #1f2328;
}
.markdown-body span.align-center {
  display: block;
  overflow: hidden;
  clear: both;
}
.markdown-body span.align-center > span {
  display: block;
  margin: 13px auto 0;
  overflow: hidden;
  text-align: center;
}
.markdown-body span.align-center span img {
  margin: 0 auto;
  text-align: center;
}
.markdown-body span.align-right {
  display: block;
  overflow: hidden;
  clear: both;
}
.markdown-body span.align-right > span {
  display: block;
  margin: 13px 0 0;
  overflow: hidden;
  text-align: right;
}
.markdown-body span.align-right span img {
  margin: 0;
  text-align: right;
}
.markdown-body span.float-left {
  display: block;
  float: left;
  margin-right: 13px;
  overflow: hidden;
}
.markdown-body span.float-left span {
  margin: 13px 0 0;
}
.markdown-body span.float-right {
  display: block;
  float: right;
  margin-left: 13px;
  overflow: hidden;
}
.markdown-body span.float-right > span {
  display: block;
  margin: 13px auto 0;
  overflow: hidden;
  text-align: right;
}
.markdown-body code,
.markdown-body tt {
  padding: 0.2em 0.4em;
  margin: 0;
  font-size: 85%;
  white-space: break-spaces;
  background-color: rgba(175, 184, 193, 0.2);
  border-radius: 6px;
}
.markdown-body code br,
.markdown-body tt br {
  display: none;
}
.markdown-body del code {
  text-decoration: inherit;
}
.markdown-body samp {
  font-size: 85%;
}
.markdown-body pre code {
  font-size: 100%;
}
.markdown-body pre > code {
  padding: 0;
  margin: 0;
  word-break: normal;
  white-space: pre;
  background: 0 0;
  border: 0;
}
.markdown-body .highlight {
  margin-bottom: 16px;
}
.markdown-body .highlight pre {
  margin-bottom: 0;
  word-break: normal;
}
.markdown-body .highlight pre,
.markdown-body pre {
  padding: 16px;
  overflow: auto;
  font-size: 85%;
  line-height: 1.45;
  color: #1f2328;
  background-color: #f6f8fa;
  border-radius: 6px;
}
.markdown-body pre code,
.markdown-body pre tt {
  display: inline;
  max-width: auto;
  padding: 0;
  margin: 0;
  overflow: visible;
  line-height: inherit;
  word-wrap: normal;
  background-color: transparent;
  border: 0;
}
.markdown-body .csv-data td,
.markdown-body .csv-data th {
  padding: 5px;
  overflow: hidden;
  font-size: 12px;
  line-height: 1;
  text-align: left;
  white-space: nowrap;
}
.markdown-body .csv-data .blob-num {
  padding: 10px 8px 9px;
  text-align: right;
  background: #fff;
  border: 0;
}
.markdown-body .csv-data tr {
  border-top: 0;
}
.markdown-body .csv-data th {
  font-weight: 600;
  background: #f6f8fa;
  border-top: 0;
}
.markdown-body [data-footnote-ref]::before {
  content: "[";
}
.markdown-body [data-footnote-ref]::after {
  content: "]";
}
.markdown-body .footnotes {
  font-size: 12px;
  color: #656d76;
  border-top: 1px solid #d0d7de;
}
.markdown-body .footnotes ol {
  padding-left: 16px;
}
.markdown-body .footnotes ol ul {
  display: inline-block;
  padding-left: 16px;
  margin-top: 16px;
}
.markdown-body .footnotes li {
  position: relative;
}
.markdown-body .footnotes li:target::before {
  position: absolute;
  top: -8px;
  right: -8px;
  bottom: -8px;
  left: -24px;
  pointer-events: none;
  content: "";
  border: 2px solid #0969da;
  border-radius: 6px;
}
.markdown-body .footnotes li:target {
  color: #1f2328;
}
.markdown-body .footnotes .data-footnote-backref g-emoji {
  font-family: monospace;
}
.markdown-body .pl-c {
  color: #6e7781;
}
.markdown-body .pl-c1,
.markdown-body .pl-s .pl-v {
  color: #0550ae;
}
.markdown-body .pl-e,
.markdown-body .pl-en {
  color: #6639ba;
}
.markdown-body .pl-s .pl-s1,
.markdown-body .pl-smi {
  color: #24292f;
}
.markdown-body .pl-ent {
  color: #116329;
}
.markdown-body .pl-k {
  color: #cf222e;
}
.markdown-body .pl-pds,
.markdown-body .pl-s,
.markdown-body .pl-s .pl-pse .pl-s1,
.markdown-body .pl-sr,
.markdown-body .pl-sr .pl-cce,
.markdown-body .pl-sr .pl-sra,
.markdown-body .pl-sr .pl-sre {
  color: #0a3069;
}
.markdown-body .pl-smw,
.markdown-body .pl-v {
  color: #953800;
}
.markdown-body .pl-bu {
  color: #82071e;
}
.markdown-body .pl-ii {
  color: #f6f8fa;
  background-color: #82071e;
}
.markdown-body .pl-c2 {
  color: #f6f8fa;
  background-color: #cf222e;
}
.markdown-body .pl-sr .pl-cce {
  font-weight: 700;
  color: #116329;
}
.markdown-body .pl-ml {
  color: #3b2300;
}
.markdown-body .pl-mh,
.markdown-body .pl-mh .pl-en,
.markdown-body .pl-ms {
  font-weight: 700;
  color: #0550ae;
}
.markdown-body .pl-mi {
  font-style: italic;
  color: #24292f;
}
.markdown-body .pl-mb {
  font-weight: 700;
  color: #24292f;
}
.markdown-body .pl-md {
  color: #82071e;
  background-color: #ffebe9;
}
.markdown-body .pl-mi1 {
  color: #116329;
  background-color: #dafbe1;
}
.markdown-body .pl-mc {
  color: #953800;
  background-color: #ffd8b5;
}
.markdown-body .pl-mi2 {
  color: #eaeef2;
  background-color: #0550ae;
}
.markdown-body .pl-mdr {
  font-weight: 700;
  color: #8250df;
}
.markdown-body .pl-ba {
  color: #57606a;
}
.markdown-body .pl-sg {
  color: #8c959f;
}
.markdown-body .pl-corl {
  text-decoration: underline;
  color: #0a3069;
}
.markdown-body g-emoji {
  display: inline-block;
  min-width: 1ch;
  font-family: "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol";
  font-size: 1em;
  font-style: normal !important;
  font-weight: 400;
  line-height: 1;
  vertical-align: -0.075em;
}
.markdown-body g-emoji img {
  width: 1em;
  height: 1em;
}
.markdown-body .task-list-item {
  list-style-type: none;
}
.markdown-body .task-list-item label {
  font-weight: 400;
}
.markdown-body .task-list-item.enabled label {
  cursor: pointer;
}
.markdown-body .task-list-item + .task-list-item {
  margin-top: 4px;
}
.markdown-body .task-list-item .handle {
  display: none;
}
.markdown-body .task-list-item-checkbox {
  margin: 0 0.2em 0.25em -1.4em;
  vertical-align: middle;
}
.markdown-body .contains-task-list:dir(rtl) .task-list-item-checkbox {
  margin: 0 -1.6em 0.25em 0.2em;
}
.markdown-body .contains-task-list {
  position: relative;
}
.markdown-body
  .contains-task-list:focus-within
  .task-list-item-convert-container,
.markdown-body .contains-task-list:hover .task-list-item-convert-container {
  display: block;
  width: auto;
  height: 24px;
  overflow: visible;
  clip: auto;
}
.markdown-body .QueryBuilder .qb-entity {
  color: #6639ba;
}
.markdown-body .QueryBuilder .qb-constant {
  color: #0550ae;
}
.markdown-body ::-webkit-calendar-picker-indicator {
  filter: invert(50%);
}
.markdown-body .markdown-alert {
  padding: 0 1em;
  margin-bottom: 16px;
  color: inherit;
  border-left: 0.25em solid #d0d7de;
}
.markdown-body .markdown-alert > :first-child {
  margin-top: 0;
}
.markdown-body .markdown-alert > :last-child {
  margin-bottom: 0;
}
.markdown-body .markdown-alert.markdown-alert-note {
  border-left-color: #0969da;
}
.markdown-body .markdown-alert.markdown-alert-important {
  border-left-color: #8250df;
}
.markdown-body .markdown-alert.markdown-alert-warning {
  border-left-color: #9a6700;
}
```

## File: `app/assets/stylesheets/medium-style.css`

```
.medium-container {
  all: revert;
  font-family: Georgia, "Times New Roman", Times, serif;
}
.medium-container * {
  all: revert;
}
.medium,
.medium-wide {
  font-family: Georgia, "Times New Roman", Times, serif;
  font-size: 21px;
  line-height: 1.58;
  letter-spacing: -0.003em;
  color: rgba(41, 41, 41, 1);
  margin: 0 auto;
  padding: 0 50px;
}
.medium {
  max-width: 768px;
}
.medium-wide {
  max-width: 1280px;
}

.medium h1,
.medium-wide h1 {
  font-family:
    -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
  font-size: 42px;
  font-weight: 700;
  line-height: 1.04;
  letter-spacing: -0.028em;
  margin: 56px 0 -13px;
}
.medium h2,
.medium-wide h2 {
  font-family:
    -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
  font-size: 34px;
  font-weight: 700;
  line-height: 1.15;
  margin: 48px 0 -13px;
}
.medium p,
.medium-wide p {
  margin: 29px 0;
  line-height: 1.58;
}
.medium blockquote,
.medium-wide blockquote {
  font-style: italic;
  font-size: 24px;
  line-height: 1.48;
  border-left: 3px solid rgba(41, 41, 41, 1);
  padding-left: 20px;
  margin: 43px 0 43px -20px;
}
.medium ul,
.medium ol,
.medium-wide ul,
.medium-wide ol {
  margin: 29px 0;
  padding-left: 30px;
}
.medium li,
.medium-wide li {
  margin: 14px 0;
  line-height: 1.58;
}
.medium pre,
.medium-wide pre {
  background: #f8f8f8;
  border-radius: 3px;
  padding: 20px;
  margin: 29px 0;
  overflow-x: auto;
  font-family: "SF Mono", Monaco, monospace;
  font-size: 16px;
  line-height: 1.45;
}
.medium code,
.medium-wide code {
  background: rgba(0, 0, 0, 0.05);
  border-radius: 2px;
  padding: 3px 4px;
  font-family: "SF Mono", Monaco, monospace;
  font-size: 16px;
}
```

## File: `app/assets/stylesheets/syntax-highlighting.css`

```
.highlight table td { padding: 5px; }
.highlight table pre { margin: 0; }
.highlight, .highlight .w {
  color: #24292f;
  background-color: #f6f8fa;
}
.highlight .k, .highlight .kd, .highlight .kn, .highlight .kp, .highlight .kr, .highlight .kt, .highlight .kv {
  color: #cf222e;
}
.highlight .gr {
  color: #f6f8fa;
}
.highlight .gd {
  color: #82071e;
  background-color: #ffebe9;
}
.highlight .nb {
  color: #953800;
}
.highlight .nc {
  color: #953800;
}
.highlight .no {
  color: #953800;
}
.highlight .nn {
  color: #953800;
}
.highlight .sr {
  color: #116329;
}
.highlight .na {
  color: #116329;
}
.highlight .nt {
  color: #116329;
}
.highlight .gi {
  color: #116329;
  background-color: #dafbe1;
}
.highlight .ges {
  font-weight: bold;
  font-style: italic;
}
.highlight .kc {
  color: #0550ae;
}
.highlight .l, .highlight .ld, .highlight .m, .highlight .mb, .highlight .mf, .highlight .mh, .highlight .mi, .highlight .il, .highlight .mo, .highlight .mx {
  color: #0550ae;
}
.highlight .sb {
  color: #0550ae;
}
.highlight .bp {
  color: #0550ae;
}
.highlight .ne {
  color: #0550ae;
}
.highlight .nl {
  color: #0550ae;
}
.highlight .py {
  color: #0550ae;
}
.highlight .nv, .highlight .vc, .highlight .vg, .highlight .vi, .highlight .vm {
  color: #0550ae;
}
.highlight .o, .highlight .ow {
  color: #0550ae;
}
.highlight .gh {
  color: #0550ae;
  font-weight: bold;
}
.highlight .gu {
  color: #0550ae;
  font-weight: bold;
}
.highlight .s, .highlight .sa, .highlight .sc, .highlight .dl, .highlight .sd, .highlight .s2, .highlight .se, .highlight .sh, .highlight .sx, .highlight .s1, .highlight .ss {
  color: #0a3069;
}
.highlight .nd {
  color: #8250df;
}
.highlight .nf, .highlight .fm {
  color: #8250df;
}
.highlight .err {
  color: #f6f8fa;
  background-color: #82071e;
}
.highlight .c, .highlight .ch, .highlight .cd, .highlight .cm, .highlight .cp, .highlight .cpf, .highlight .c1, .highlight .cs {
  color: #6e7781;
}
.highlight .gl {
  color: #6e7781;
}
.highlight .gt {
  color: #6e7781;
}
.highlight .ni {
  color: #24292f;
}
.highlight .si {
  color: #24292f;
}
.highlight .ge {
  color: #24292f;
  font-style: italic;
}
.highlight .gs {
  color: #24292f;
  font-weight: bold;
}
```

## File: `app/assets/tailwind/application.css`

```
/* app/assets/tailwind/application.css */
@import "tailwindcss";
@import "../stylesheets/layout_switcher.css";

.blue-theme .blog-title {
  @apply text-blue-600;
}
.blue-theme .theme-accent {
  @apply bg-blue-500 text-white;
}

.green-theme .blog-title {
  @apply text-green-600;
}
.green-theme .theme-accent {
  @apply bg-green-500 text-white;
}

.purple-theme .blog-title {
  @apply text-purple-600;
}
.purple-theme .theme-accent {
  @apply bg-purple-500 text-white;
}

.gray-theme .blog-title {
  @apply text-gray-600;
}
.gray-theme .theme-accent {
  @apply bg-gray-500 text-white;
}

[data-markdown-preview-target="preview"] img {
  width: 100%;
  height: auto;
  object-fit: contain;
  border-radius: 4px;
  margin: 10px 0;
}

/* 公開記事の画像 */
.article-content img {
  max-width: 100%;
  height: auto;
  max-height: 500px;
  object-fit: contain;
  border-radius: 4px;
  margin: 10px 0;
}

/* app/assets/stylesheets/application.css */
.article-content img {
  max-width: 100%;
  height: auto;
  max-height: 500px;
  object-fit: contain;
  border-radius: 4px;
  margin: 15px auto;
  display: block;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
}

.tab-container {
  margin: 20px 0;
}

.tab-buttons {
  display: flex;
  border-bottom: 2px solid #ddd;
  margin-bottom: 20px;
}

.tab-button {
  padding: 10px 20px;
  border: none;
  background: #f5f5f5;
  cursor: pointer;
  border-top: 2px solid transparent;
  margin-right: 2px;
}

.tab-button.active {
  background: white;
  border-top-color: #007bff;
  font-weight: bold;
}

.tab-content {
  display: none;
}

.tab-content.active {
  display: block;
}
```

## File: `app/javascript/application.js`

```
// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails";
import "controllers";
import "flash";
```

## File: `app/javascript/controllers/application.js`

```
import { Application } from "@hotwired/stimulus"

const application = Application.start()

// Configure Stimulus development experience
application.debug = false
window.Stimulus   = application

export { application }
```

## File: `app/javascript/controllers/category_tabs_controller.js`

```
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["content", "button"];

  connect() {
    this.showTab("ja");
  }

  switchTab(event) {
    const targetTab = event.currentTarget.dataset.target;
    this.showTab(targetTab);
  }

  showTab(tab) {
    this.buttonTargets.forEach((button) => {
      button.classList.remove("active");
    });

    this.contentTargets.forEach((content) => {
      content.classList.remove("active");
    });

    const activeButton = this.buttonTargets.find(
      (button) => button.dataset.target === tab,
    );
    const activeContent = this.contentTargets.find(
      (content) => content.dataset.tab === tab,
    );

    activeButton?.classList.add("active");
    activeContent?.classList.add("active");
  }
}
```

## File: `app/javascript/controllers/hello_controller.js`

```
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.textContent = "Hello World!"
  }
}
```

## File: `app/javascript/controllers/image_upload_controller.js`

```
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["textarea"];

  selectImage() {
    console.log("selectImage called!"); // ← 追加
    const input = document.createElement("input");
    input.type = "file";
    input.accept = "image/*";
    input.addEventListener("change", (e) => {
      const file = e.target.files[0];
      if (file) {
        this.uploadImage(file);
      }
    });
    input.click();
  }

  uploadImage(file) {
    console.log("uploadImage called with:", file);
    const formData = new FormData();
    formData.append("image", file);

    const locale = window.location.pathname.split("/")[1];
    const url = `/${locale}/admin/images`;

    fetch(url, {
      method: "POST",
      headers: {
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")
          .content,
      },
      body: formData,
    })
      .then((response) => response.json())
      .then((data) => {
        console.log("Data received:", data);
        if (data.url) {
          this.insertImageMarkdown(data.url, file.name);
        }
      });
  }

  insertImageMarkdown(url, filename) {
    const textarea = this.textareaTarget;
    const cursorPos = textarea.selectionStart;
    const textBefore = textarea.value.substring(0, cursorPos);
    const textAfter = textarea.value.substring(cursorPos);
    const markdown = `![${filename}](${url})`;

    textarea.value = textBefore + markdown + textAfter;
    textarea.focus();
    textarea.setSelectionRange(
      cursorPos + markdown.length,
      cursorPos * markdown.length,
    );

    textarea.dispatchEvent(new Event("input"));
  }
}
```

## File: `app/javascript/controllers/index.js`

```
// Import and register all your controllers from the importmap via controllers/**/*_controller
import { application } from "controllers/application"
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
eagerLoadControllersFrom("controllers", application)
```

## File: `app/javascript/controllers/layout_switcher_controller.js`

```
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["textArea", "preview", "originalPreview", "buttons"];
  static values = { currentMode: String, translationMode: Boolean };

  connect() {
    this.currentModeValue = "split";
    this.updateLayout();
  }

  get isTranslationPage() {
    return this.translationModeValue === true;
  }

  switchToSplit() {
    this.currentModeValue = "split";
    this.updateLayout();
  }

  switchToTextOnly() {
    this.currentModeValue = "text-only";
    this.updateLayout();
  }

  switchToPreviewOnly() {
    this.currentModeValue = "preview-only";
    this.updateLayout();
  }

  switchToOriginalPreview() {
    if (!this.isTranslationPage) return;
    this.currentModeValue = "original-preview";
    this.updateLayout();
  }

  updateLayout() {
    this.element.classList.remove(
      "mode-split",
      "mode-text-only",
      "mode-preview-only",
      "mode-original-preview",
    );
    this.element.classList.add(`mode-${this.currentModeValue}`);
    this.updateButtonStates();
  }

  updateButtonStates() {
    this.buttonsTarget.querySelectorAll("button").forEach((button) => {
      button.classList.toggle(
        "active",
        button.dataset.mode === this.currentModeValue,
      );
    });
  }
}
```

## File: `app/javascript/controllers/markdown_preview_controller.js`

```
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["input", "preview", "titlePreview"];
  static values = { url: String };

  connect() {
    this.timeout = null;
    this.fetchPreview();
    this.updateTitlePreview();
    this.adjustHeight(this.inputTarget);
  }

  preview() {
    this.adjustHeight(this.inputTarget);
    this.updateTitlePreview();
    console.log("preview method called");
    clearTimeout(this.timeout);
    this.timeout = setTimeout(() => {
      this.fetchPreview();
    }, 50);
  }

  updateTitlePreview() {
    const title = document.querySelector('[data-field="title"]').value || "";
    this.titlePreviewTarget.innerHTML = `<h1>${title || "title"}</h1>`;
  }

  fetchPreview() {
    const content = this.inputTarget.value;

    console.log("=== プレビューデバッグ ===");
    console.log("URL:", this.urlValue);
    console.log("Content:", content);
    console.log("Content length:", content.length);

    if (content.trim() === "") {
      this.previewTarget.innerHTML = "<p>プレビューがここに表示されます</p>";
      return;
    }

    fetch(this.urlValue, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')
          .content,
      },
      body: JSON.stringify({ content: content }),
    })
      .then((response) => {
        console.log("Response status:", response.status);
        return response.json();
      })
      .then((data) => {
        console.log("Response data:", data);
        this.previewTarget.innerHTML = data.html;
      })
      .catch((error) => {
        console.error("プレビューエラー:", error);
        this.previewTarget.innerHTML =
          "<p>プレビューの読み込みでエラーが発生しました</p>";
      });
  }

  adjustHeight(element) {
    element.style.height = "auto";
    const maxHeight = window.innerHeight * 0.8;
    element.style.height = Math.min(element.scrollHeight, maxHeight) + "px";
  }
}
```

## File: `app/javascript/flash.js`

```
function initFlashMessages() {
  const flashMessages = document.querySelectorAll(".flash-message");

  flashMessages.forEach(function (message) {
    setTimeout(function () {
      message.style.opacity = "0";
      setTimeout(function () {
        message.remove();
      }, 300);
    }, 3000);
  });
}

document.addEventListener("DOMContentLoaded", initFlashMessages);
document.addEventListener("turbo:load", initFlashMessages);
```

