# Project Code Export (MVC + Routes + Schema)
Exported at: 2025-12-27 12:32:12 +0900

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

## File: `app/models/contact.rb`

```
class Contact < ApplicationRecord
  validates :name, presence: true, length: { maximum: 100 }
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :subject, presence: true, length: { maximum: 200 }
  validates :message, presence: true, length: { maximum: 2000 }
  scope :unresolved, -> { where(resolved: false) }
  scope :resolved, -> { where(resolved: true) }
  scope :recent, -> { order(created_at: :desc) }

  def mark_as_resolved!
    update!(resolved: true)
  end

  def mark_as_unresolved!
    update!(resolved: false)
  end
end
```

## File: `app/models/tag.rb`

```
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
```

## File: `app/models/user.rb`

```
class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  # devise :database_authenticatable, :registerable,
  #        :recoverable, :rememberable, :validatable, :omniauthable, omniauth_providers: [ :github ]


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
end
```

## File: `app/controllers/admin/articles_controller.rb`

```
# app/controllers/admin/articles_controller.rb
class Admin::ArticlesController < Admin::BaseController
  def index
    @articles = Article.includes(:user, :category)
                      .order(created_at: :desc)
                      .page(params[:page])
                      .per(20)
  end

  def destroy
    @article = Article.find(params[:id])
    if @article.destroy
      redirect_to admin_articles_path, notice: "記事「#{@article.title}」を削除しました"
    else
      redirect_to admin_articles_path, alert: "削除に失敗しました"
    end
  end
end
```

## File: `app/controllers/admin/base_controller.rb`

```
class Admin::BaseController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin
  layout "admin"

  private

  def require_admin
    redirect_to root_path, alert: "管理者権限が必要でる" unless current_user&.admin?
  end
end
```

## File: `app/controllers/admin/contacts_controller.rb`

```
class Admin::ContactsController < Admin::BaseController
  def index
    @contacts = Contact.order(created_at: :desc)
                      .page(params[:page])
                      .per(20)
  end

  def show
    @contact = Contact.find(params[:id])
  end

  def update
    @contact = Contact.find(params[:id])

    if @contact.update(contact_params)
      status = @contact.resolved? ? "対応済み" : "未対応"
      redirect_to admin_contacts_path, notice: "お問い合わせを#{status}にしました"
    else
      redirect_to admin_contacts_path, alert: "操作に失敗しました"
    end
  end

  private

  def contact_params
    params.require(:contact).permit(:resolved)
  end
end
```

## File: `app/controllers/admin/dashboard_controller.rb`

```
class Admin::DashboardController < Admin::BaseController
  def index
    @stats = {
      total_users: User.count,
      total_articles: Article.count,
      published_articles: Article.published.count,
      this_month_users: User.where(created_at: Time.current.beginning_of_month..).count,
      total_contacts: Contact.count,
      unresolved_contacts: Contact.where(resolved: false).count
    }
  end
end
```

## File: `app/controllers/admin/users_controller.rb`

```
class Admin::UsersController < Admin::BaseController
  def index
    @users = User.includes(:articles).order(created_at: :desc)

    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @users = @users.where(
        "username ILIKE ? OR email ILIKE ?",
        search_term,
        search_term
      )
    end

    @users = @users.page(params[:page]).per(20)
  end

  def show
    @user = User.find(params[:id])
    @articles = @user.articles.includes(:category).order(created_at: :desc).limit(10)
  end

  def update
    @user = User.find(params[:id])

    if @user.admin?
      return redirect_to admin_users_path, alert: "管理者ユーザーの状態は変更できません"
    end

    old_status = @user.status

    if @user.update(user_params)
      action = @user.suspended? ? "停止" : "復旧"
      redirect_to admin_users_path, notice: "#{@user.username}のアカウントを#{action}しました"
    else
      redirect_to admin_users_path, alert: "操作に失敗しました"
    end
  end

  private

  def user_params
    params.require(:user).permit(:status)
  end
end
```

## File: `app/controllers/application_controller.rb`

```
class ApplicationController < ActionController::Base
  include Authorization
  before_action :set_locale
  before_action :set_blog_setting
  before_action :configure_permitted_parameters, if: :devise_controller?


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
    elsif user_signed_in?
      @blog_setting = current_user.blog_setting
    end
  end

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :username ])
    devise_parameter_sanitizer.permit(:account_update, keys: [ :username ])
  end
end
```

## File: `app/controllers/articles_controller.rb`

```
class ArticlesController < ApplicationController
  before_action :set_user
  before_action :set_locale
  def index
    @filter = ArticleFilterQuery.new(params.merge(user: @user))
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

  def set_user
    @user = User.find_by!(username: params[:username])
  end

  def set_locale
    I18n.locale = params[:locale] || I18n.default_locale
  end
end
```

## File: `app/controllers/comments_controller.rb`

```
class CommentsController < ApplicationController
  def create
    Rails.logger.info "XXXXXXXXXXXXXXXXXcreate calledXXXXXXXXXXXXXXXXXX"
    Rails.logger.info "Params: #{params.inspect}"
    @article = Article.find(params[:article_id])
    @comment = Comment.new(comment_params)
    @comment.article = @article

    if @comment.save
      redirect_to user_article_path(@article.user.username, @article.id, locale: params[:locale]), notice: "コメントを投稿しました"
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

## File: `app/controllers/contacts_controller.rb`

```
class ContactsController < ApplicationController
  def new
    @contact = Contact.new
  end

  def create
    @contact = Contact.new(contact_params)

    if @contact.save
      ContactMailer.new_contact(@contact).deliver_now
      redirect_to new_contact_path, notice: "お問い合わせを送信しました。ありがとうございます。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def contact_params
    params.require(:contact).permit(:name, :email, :subject, :message)
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
    params.require(:article).permit(:title, :content, :locale, :status, :category_id, :tag_list, :cover_image)
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
    params.require(:blog_setting).permit(:blog_title_ja, :blog_title_en, :blog_subtitle_ja, :blog_subtitle_en, :theme_color, :header_image, :layout_style, :show_hero_thumbnail)
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

    respond_to do |format|
      if @category.save
        format.html { redirect_to dashboard_categories_path(locale: params[:locale]), notice: "カテゴリが作成されました" }
        format.json { render json: { category: { id: @category.id, name: @category.name } } }
      else
        format.html { render new }
        format.json { render json: { error: @category.errors.full_messages.join(", ") }, status: 422 }
      end
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

## File: `app/controllers/dashboard/exports_controller.rb`

```
class Dashboard::ExportsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_article

  def show
    # ファイル名を生成（日本語文字の処理）
    safe_title = sanitize_filename(@article.title)
    filename = "#{safe_title}_#{@article.locale}.md"

    # Markdownコンテンツを生成
    markdown_content = generate_markdown_content(@article)

    # ファイルとしてダウンロード
    send_data markdown_content,
              filename: filename,
              type: "text/markdown",
              disposition: "attachment"
  end

  private

  def set_article
    @article = current_user.articles.find(params[:article_id])
  end


  def sanitize_filename(title)
    # 日本語（Unicode文字）と英数字、ハイフン、アンダースコア以外を削除
    title.gsub(/[^\p{L}\p{N}\s-]/u, "").gsub(/\s+/, "_").strip
  end

  def generate_markdown_content(article)
    content = []

    # メタデータ部分
    content << "# #{article.title}"
    content << ""
    content << "**カテゴリ**: #{article.category&.name || '未設定'}"
    content << "**タグ**: #{article.tags.pluck(:name).join(', ')}" if article.tags.any?
    content << "**投稿日**: #{article.published_at&.strftime('%Y年%m月%d日') || article.created_at.strftime('%Y年%m月%d日')}"
    content << ""
    content << "---"
    content << ""

    # 記事本文
    content << article.content

    content.join("\n")
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
    params.require(:user).permit(:nickname_ja, :nickname_en, :bio_ja, :bio_en, :website, :location_ja, :location_en, :twitter_handle, :facebook_handle, :linkedin_handle, :github_handle, :qiita_handle, :zenn_handle, :hatena_handle, :avatar)
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
    @translation.user = current_user
    # @translation.tags = @original_article.tags
    @translation.tag_list = @original_article.tag_list
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
    params.require(:article).permit(:title, :content, :status, :category_id, :tag_list, :cover_image)
  end
end
```

## File: `app/controllers/legal_controller.rb`

```
# app/controllers/legal_controller.rb
class LegalController < ApplicationController
  def terms_of_service
  end

  def privacy_policy
  end

  def disclaimer
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
    Rails.logger.info "Search keyword: #{@search_keyword}"
    @articles = if @search_keyword.present?
                  user = User.find_by(username: params[:username])
                  user.articles.published
                    .where(locale: params[:locale])
                    .search(@search_keyword)
                    .includes(:category, :tags)
                    .order(published_at: :desc)
                    .page(params[:page]).per(10)
    else
                  current_user.articles.none.page(1)
    end
    @filter = ArticleFilterQuery.new(params.merge(user: user))
  end
end
```

## File: `app/controllers/users/comments_controller.rb`

```
class CommentsController < ApplicationController
  def create
    Rails.logger.info "$$$$$$$$$$create called$$$$$$$$$$$"
    @article = Article.find_by(params[:article_id])
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

## File: `app/controllers/users/omniauth_callbacks_controller.rb`

```
class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  skip_before_action :verify_authenticity_token, only: :github

  def github
    handle_omniauth("github")
  end

  def google_oauth2
    handle_omniauth("google_oauth2")
  end

  def handle_omniauth(provider)
    result = User.from_omniauth(request.env["omniauth.auth"])
    @user = result[:user]

    if @user.persisted?
      if result[:is_new]
        flash[:notice] = "アカウントを作成しました"
      else
        flash[:notice] = "既存アカウントでログインしました"
      end
      redirect_to dashboard_articles_path
    else
      rediret_to dashboard_articles_path
      session["devise.#{provider}_data"] = request.env["omniauth.auth"].except("extra")
        redirect_to new_user_registration_url
    end
  end

  def failure
    redirect_to root_path
  end
end
```

## File: `app/controllers/welcome_controller.rb`

```
class WelcomeController < ApplicationController
  def index
  end
end
```

## File: `app/views/admin/articles/index.html.slim`

```
h1.text-2xl.font-bold.mb-6 記事管理

.bg-white.rounded-lg.border.border-gray-200.overflow-hidden
  table.w-full
    thead.bg-gray-50
      tr
        th.px-6.py-3.text-left.text-xs.font-medium.text-gray-500.uppercase ID
        th.px-6.py-3.text-left.text-xs.font-medium.text-gray-500.uppercase タイトル
        th.px-6.py-3.text-left.text-xs.font-medium.text-gray-500.uppercase 作者
        th.px-6.py-3.text-left.text-xs.font-medium.text-gray-500.uppercase 言語
        th.px-6.py-3.text-left.text-xs.font-medium.text-gray-500.uppercase ステータス
        th.px-6.py-3.text-left.text-xs.font-medium.text-gray-500.uppercase 投稿日
        th.px-6.py-3.text-left.text-xs.font-medium.text-gray-500.uppercase アクション
    tbody.divide-y.divide-gray-200
      - @articles.each do |article|
        tr
          td.px-6.py-4.text-sm= article.id
          td.px-6.py-4.text-sm.font-medium
            = link_to truncate(article.title, length: 50), user_article_path(article.user.username, article.id, locale: article.locale), target: "_blank", class: "text-blue-600 hover:text-blue-800"
          td.px-6.py-4.text-sm= article.user.username
          td.px-6.py-4.text-sm= article.locale == 'ja' ? '日本語' : 'English'
          td.px-6.py-4.text-sm
            - if article.published?
              span.bg-green-100.text-green-800.px-2.py-1.rounded.text-xs 公開
            - else
              span.bg-gray-100.text-gray-800.px-2.py-1.rounded.text-xs 下書き
          td.px-6.py-4.text-sm= article.created_at.strftime('%Y/%m/%d')
          td.px-6.py-4.text-sm
            = link_to "削除", admin_article_path(article), data: { "turbo-method": "delete", "turbo-confirm": "記事を削除しますか？" }, class: "text-red-600 hover:text-red-800"

= paginate @articles if respond_to?(:paginate)
```

## File: `app/views/admin/contacts/index.html.slim`

```
h1.text-2xl.font-bold.mb-6 問い合わせ管理

.bg-white.rounded-lg.border.border-gray-200.overflow-hidden
  table.w-full
    thead.bg-gray-50
      tr
        th.px-6.py-3.text-left.text-xs.font-medium.text-gray-500.uppercase ID
        th.px-6.py-3.text-left.text-xs.font-medium.text-gray-500.uppercase 名前
        th.px-6.py-3.text-left.text-xs.font-medium.text-gray-500.uppercase 件名
        th.px-6.py-3.text-left.text-xs.font-medium.text-gray-500.uppercase 受信日
        th.px-6.py-3.text-left.text-xs.font-medium.text-gray-500.uppercase 状態
        th.px-6.py-3.text-left.text-xs.font-medium.text-gray-500.uppercase アクション
    tbody.divide-y.divide-gray-200
      - @contacts.each do |contact|
        tr
          td.px-6.py-4.text-sm= contact.id
          td.px-6.py-4.text-sm.font-medium= contact.name
          td.px-6.py-4.text-sm
            = link_to truncate(contact.subject, length: 50), admin_contact_path(contact), class: "text-blue-600 hover:text-blue-800"
          td.px-6.py-4.text-sm= contact.created_at.strftime('%Y/%m/%d %H:%M')
          td.px-6.py-4.text-sm
            - if contact.resolved?
              span.bg-green-100.text-green-800.px-2.py-1.rounded.text-xs 対応済み
            - else
              span.bg-red-100.text-red-800.px-2.py-1.rounded.text-xs 未対応
          td.px-6.py-4.text-sm
            = form_with model: [:admin, contact], local: true, class: "inline" do |f|
              = f.hidden_field :resolved, value: !contact.resolved?
              = f.submit contact.resolved? ? '未対応にする' : '対応済みにする', 
                  class: "text-sm px-2 py-1 rounded border #{contact.resolved? ? 'text-orange-600 hover:text-orange-800 border-orange-300' : 'text-green-600 hover:text-green-800 border-green-300'} bg-white hover:bg-gray-50",
                  data: { turbo_confirm: "#{contact.resolved? ? '未対応' : '対応済み'}にしますか？" }

= paginate @contacts if respond_to?(:paginate)
```

## File: `app/views/admin/contacts/show.html.slim`

```
.mb-6
  = link_to "← 問い合わせ一覧に戻る", admin_contacts_path, class: "text-blue-600 hover:text-blue-800"

h1.text-2xl.font-bold.mb-6 問い合わせ詳細

.bg-white.rounded-lg.border.border-gray-200.p-6
  .grid.grid-cols-2.gap-4.mb-6
    div
      .text-sm.text-gray-600 お名前
      .font-semibold= @contact.name
    div
      .text-sm.text-gray-600 メールアドレス
      .font-semibold= @contact.email
    div
      .text-sm.text-gray-600 件名
      .font-semibold= @contact.subject
    div
      .text-sm.text-gray-600 受信日
      .font-semibold= @contact.created_at.strftime('%Y年%m月%d日 %H:%M')
    div
      .text-sm.text-gray-600 対応状態
      div
        - if @contact.resolved?
          span.bg-green-100.text-green-800.px-2.py-1.rounded.text-xs 対応済み
        - else
          span.bg-red-100.text-red-800.px-2.py-1.rounded.text-xs 未対応

  .mb-6
    .text-sm.text-gray-600.mb-2 お問い合わせ内容
    .bg-gray-50.rounded.p-4= simple_format(@contact.message)

  .flex.gap-3
    = form_with model: [:admin, @contact], local: true, class: "inline" do |f|
      = f.hidden_field :resolved, value: !@contact.resolved?
      = f.submit @contact.resolved? ? '未対応にする' : '対応済みにする', 
          class: "btn-unified"
```

## File: `app/views/admin/dashboard/index.html.slim`

```
h1.text-2xl.font-bold.mb-6 管理ダッシュボード

.grid.grid-cols-1.md:grid-cols-3.gap-6.mb-8
  .bg-white.rounded-lg.border.border-gray-200.p-6
    h3.text-lg.font-semibold.text-gray-900.mb-2 ユーザー
    p.text-3xl.font-bold.text-blue-600= @stats[:total_users]
    p.text-sm.text-gray-500 今月の新規: #{@stats[:this_month_users]}名

  .bg-white.rounded-lg.border.border-gray-200.p-6
    h3.text-lg.font-semibold.text-gray-900.mb-2 記事
    p.text-3xl.font-bold.text-green-600= @stats[:total_articles]
    p.text-sm.text-gray-500 公開記事: #{@stats[:published_articles]}件

  .bg-white.rounded-lg.border.border-gray-200.p-6
    h3.text-lg.font-semibold.text-gray-900.mb-2 問い合わせ
    p.text-3xl.font-bold.text-orange-600= @stats[:total_contacts]
    p.text-sm.text-gray-500 未対応: #{@stats[:unresolved_contacts]}件

.bg-white.rounded-lg.border.border-gray-200.p-6
  h3.text-lg.font-semibold.mb-4 クイックアクション
  .flex.gap-4
    = link_to "ユーザー管理", admin_users_path, class: "btn-unified"
    = link_to "記事管理", admin_articles_path, class: "btn-unified"
    = link_to "問い合わせ管理", admin_contacts_path, class: "btn-unified"
```

## File: `app/views/admin/users/index.html.slim`

```
.flex.justify-between.items-center.mb-6
  h1.text-2xl.font-bold ユーザー管理
  = form_with url: admin_users_path, method: :get, local: true, class: "flex gap-2" do |f|
    = f.text_field :search, placeholder: "ユーザー名・メールで検索", value: params[:search], class: "border border-gray-300 rounded px-3 py-2"
    = f.submit "検索", class: "btn-unified"

.bg-white.rounded-lg.border.border-gray-200.overflow-hidden
  table.w-full
    thead.bg-gray-50
      tr
        th.px-6.py-3.text-left.text-xs.font-medium.text-gray-500.uppercase ID
        th.px-6.py-3.text-left.text-xs.font-medium.text-gray-500.uppercase ユーザー名
        th.px-6.py-3.text-left.text-xs.font-medium.text-gray-500.uppercase メール
        th.px-6.py-3.text-left.text-xs.font-medium.text-gray-500.uppercase 記事数
        th.px-6.py-3.text-left.text-xs.font-medium.text-gray-500.uppercase 登録日
        th.px-6.py-3.text-left.text-xs.font-medium.text-gray-500.uppercase 状態
        th.px-6.py-3.text-left.text-xs.font-medium.text-gray-500.uppercase アクション
    tbody.divide-y.divide-gray-200
      - @users.each do |user|
        tr
          td.px-6.py-4.text-sm= user.id
          td.px-6.py-4.text-sm.font-medium= link_to user.username, admin_user_path(user), class: "text-blue-600 hover:text-blue-800"
          td.px-6.py-4.text-sm= user.email
          td.px-6.py-4.text-sm= user.articles.count
          td.px-6.py-4.text-sm= user.created_at.strftime('%Y/%m/%d')
          td.px-6.py-4.text-sm
            - if user.suspended?
              span.bg-red-100.text-red-800.px-2.py-1.rounded.text-xs 停止中
            - elsif user.pending?
              span.bg-yellow-100.text-yellow-800.px-2.py-1.rounded.text-xs 保留中
            - else
              span.bg-green-100.text-green-800.px-2.py-1.rounded.text-xs アクティブ
          td.px-6.py-4.text-sm
            - if user.admin?
              span.text-gray-400.text-sm 管理者
            - else
              = form_with model: [:admin, user], local: true, class: "inline" do |f|
                = f.hidden_field :status, value: user.suspended? ? 'active' : 'suspended'
                = f.submit user.suspended? ? '復旧' : '停止', 
                    class: "text-sm px-2 py-1 rounded border #{user.suspended? ? 'text-green-600 hover:text-green-800 border-green-300' : 'text-red-600 hover:text-red-800 border-red-300'} bg-white hover:bg-gray-50",
                    data: { turbo_confirm: "#{user.suspended? ? '復旧' : '停止'}しますか？" }

= paginate @users if respond_to?(:paginate)
```

## File: `app/views/admin/users/show.html.slim`

```
.mb-6
  = link_to "← ユーザー一覧に戻る", admin_users_path, class: "text-blue-600 hover:text-blue-800"

h1.text-2xl.font-bold.mb-6 ユーザー詳細

.grid.grid-cols-1.md:grid-cols-2.gap-6.mb-8
  .bg-white.rounded-lg.border.border-gray-200.p-6
    h3.text-lg.font-semibold.mb-4 基本情報
    .space-y-3
      .flex
        span.w-24.text-gray-600 ID:
        span= @user.id
      .flex
        span.w-24.text-gray-600 ユーザー名:
        span= @user.username
      .flex
        span.w-24.text-gray-600 メール:
        span= @user.email
      .flex
        span.w-24.text-gray-600 権限:
        span
          - if @user.admin?
            span.bg-red-100.text-red-800.px-2.py-1.rounded.text-xs 管理者
          - else
            span.bg-blue-100.text-blue-800.px-2.py-1.rounded.text-xs 一般
      .flex
        span.w-24.text-gray-600 登録日:
        span= @user.created_at.strftime('%Y年%m月%d日 %H:%M')
      .flex
        span.w-24.text-gray-600 状態:
        span
          - if @user.email.include?('[SUSPENDED]')
            span.bg-red-100.text-red-800.px-2.py-1.rounded.text-xs 停止中
          - else
            span.bg-green-100.text-green-800.px-2.py-1.rounded.text-xs アクティブ

  .bg-white.rounded-lg.border.border-gray-200.p-6
    h3.text-lg.font-semibold.mb-4 統計情報
    .space-y-3
      .flex
        span.w-32.text-gray-600 総記事数:
        span= @user.articles.count
      .flex
        span.w-32.text-gray-600 公開記事数:
        span= @user.articles.published.count
      .flex
        span.w-32.text-gray-600 下書き数:
        span= @user.articles.draft.count

- if @articles.any?
  .bg-white.rounded-lg.border.border-gray-200.p-6
    h3.text-lg.font-semibold.mb-4 最近の記事
    .space-y-3
      - @articles.each do |article|
        .flex.justify-between.items-center.py-2.border-b.border-gray-100
          div
            = link_to article.title, user_article_path(article.user.username, article.id, locale: article.locale), target: "_blank", class: "text-blue-600 hover:text-blue-800"
            .text-sm.text-gray-500
              = article.locale == 'ja' ? '日本語' : 'English'
              | ・
              = article.created_at.strftime('%Y/%m/%d')
          div
            - if article.published?
              span.bg-green-100.text-green-800.px-2.py-1.rounded.text-xs 公開
            - else
              span.bg-gray-100.text-gray-800.px-2.py-1.rounded.text-xs 下書き
```

## File: `app/views/articles/_hero_list_layout.html.slim`

```
- hero_article = articles.first
- list_articles = articles.offset(1).limit(10)

/ ヒーロー記事
- if hero_article
  .hero-article.mb-12
    - if @blog_setting&.show_hero_thumbnail && has_cover_image?(hero_article)
      .hero-thumbnail.mb-6.max-w-4xl.mx-auto
        = image_tag thumbnail_for_article(hero_article, @blog_setting), class: "w-full h-64 object-cover rounded-lg shadow-md"
    .article-header.max-w-4xl.mx-auto
      h1.text-4xl.font-extrabold.mb-4.text-gray-900.border-b.border-gray-500.pb-2
        = link_to hero_article.title, user_article_path(hero_article.user.username, hero_article.id, locale: params[:locale])

      .article-meta.pb-3.mb-4
        - if hero_article.category.present?
          p.pb-2
            | #{t('blog.category')}:
            = link_to hero_article.category.name, user_articles_path(params[:username], filter.filter_params.merge(category_id: hero_article.category.id))

        = render 'shared/article_tags', article: hero_article, filter_params: filter.filter_params

      .meta-content-divider.text-center.mx-8
        span.text-gray-400.text-xl • • •

    .article-content.medium-container style="all: revert;"
      div class="medium"
        = hero_article.content_html

    .article-meta.max-w-4xl.mx-auto.text-right
      p
        | #{t('blog.published_at')}:
        = hero_article.published_at&.strftime('%Y年%m月%d日')
      p
        | #{t('blog.updated_at')}:
        = hero_article.updated_at&.strftime('%Y年%m月%d日')

      - if hero_article.translation.present?
        p= link_to "#{hero_article.locale == 'ja' ? 'English' : '日本語'}版", user_article_path(hero_article.translation.user.username, hero_article.translation.id, locale: hero_article.translation.locale)

/ リスト記事
- if list_articles.any?
  .list-section.max-w-4xl.mx-auto
    h2.text-xl.font-semibold.mb-6.border-b.border-gray-200.pb-2 その他の記事
    .space-y-4
      - list_articles.each do |article|
        .list-article.border-b.border-gray-100.pb-4.last:border-b-0
          .flex.justify-between.items-start
            div.flex-1
              h3.text-lg.font-medium.mb-2
                = link_to article.title, user_article_path(article.user.username, article.id, locale: params[:locale]), class: "text-gray-900 hover:text-blue-600"
              
              .flex.items-center.gap-4.text-sm.text-gray-500.mb-2
                - if article.category.present?
                  = link_to "#{t('blog.category')}: #{article.category.name}", user_articles_path(params[:username], filter.filter_params.merge(category_id: article.category.id)), class: "bg-gray-100.px-2.py-1.rounded.text-xs hover:bg-gray-200"
              
                - if article.tags.any?
                  .flex.items-center.gap-1
                    span #{t('blog.tags')}:
                    - article.tags.limit(3).each do |tag|
                      = link_to tag.name, user_articles_path(params[:username], filter.filter_params.merge(tag_id: tag.id)), class: "inline-block bg-blue-100 text-blue-800 px-2 py-1 rounded text-xs hover:bg-blue-200"

                span= "#{t('blog.published_at')}: #{article.published_at&.strftime('%Y年%m月%d日')}"


/        | #{t('blog.published_at')}:
              /.text-gray-600.text-sm= article.content_preview(100)
              /
              /.text-gray-600.text-sm= article.content_preview(100)
            
            - if has_cover_image?(article)
              = image_tag thumbnail_for_article(article, blog_setting), 
                  class: "w-20 h-20 object-cover rounded ml-4 flex-shrink-0"

```

## File: `app/views/articles/_hero_tiles_layout.html.slim`

```
- hero_article = articles.first
- tile_articles = articles.offset(1).limit(6)

/ ヒーロー記事
- if hero_article
  .hero-article.mb-12
    - if @blog_setting&.show_hero_thumbnail && has_cover_image?(hero_article)
      .hero-thumbnail.max-w-4xl.mx-auto.mb-6
        = image_tag thumbnail_for_article(hero_article, @blog_setting), class: "w-full h-64 object-cover rounded-lg shadow-md"
    .article-header.max-w-4xl.mx-auto
      h1.text-4xl.font-extrabold.mb-4.text-gray-900.border-b.border-gray-500.pb-2
        = link_to hero_article.title, user_article_path(hero_article.user.username, hero_article.id, locale: params[:locale])

      .article-meta.pb-3.mb-4
        - if hero_article.category.present?
          p.pb-2
            | #{t('blog.category')}:
            = link_to hero_article.category.name, user_articles_path(params[:username], filter.filter_params.merge(category_id: hero_article.category.id))

        = render 'shared/article_tags', article: hero_article, filter_params: filter.filter_params

      .meta-content-divider.text-center.mx-8
        span.text-gray-400.text-xl • • •

    .article-content.medium-container style="all: revert;"
      div class="medium"
        = hero_article.content_html

    .article-meta.max-w-4xl.mx-auto.text-right
      p
        | #{t('blog.published_at')}:
        = hero_article.published_at&.strftime('%Y年%m月%d日')
      p
        | #{t('blog.updated_at')}:
        = hero_article.updated_at&.strftime('%Y年%m月%d日')

      - if hero_article.translation.present?
        p= link_to "#{hero_article.locale == 'ja' ? 'English' : '日本語'}版", user_article_path(hero_article.translation.user.username, hero_article.translation.id, locale: hero_article.translation.locale)

/ タイル記事
- if tile_articles.any?
  .tiles-section
    h2.text-xl.font-semibold.mb-6.text-center その他の記事
    .grid.grid-cols-1.md:grid-cols-2.lg:grid-cols-3.gap-6.max-w-6xl.mx-auto
      - tile_articles.each do |article|
        .tile-article
          = render 'shared/article_thumbnail', article: article, blog_setting: blog_setting, filter_params: filter.filter_params
```

## File: `app/views/articles/_linear_layout.html.slim`

```
- articles.each do |article|
  .article-item.mb-8.p-6.border-b.border-gray-500
    .article-header.max-w-3xl.mx-auto
      h2.text-4xl.font-extrabold.mb-4.mt-8.text-gray-900.border-b.border-gray-500.pb-2
        = link_to article.title, user_article_path(article.user.username, article.id, locale: params[:locale])

      .article-meta.pb-3.mb-4
        - if article.category.present?
          p.pb-2
            | #{t('blog.category')}:
            = link_to article.category.name, user_articles_path(params[:username], filter.filter_params.merge(category_id: article.category.id))

        = render 'shared/article_tags', article: article, filter_params: filter.filter_params

      .meta-content-divider.text-center.mx-8
        span.text-gray-400.text-xl • • 

    .article-content.medium-container style="all: revert;"
      div class="medium"
        = article.content_html

    .article-meta.max-w-3xl.mx-auto.text-right
      p
        | #{t('blog.published_at')}:
        = article.published_at&.strftime('%Y年%m月%d日')
      p
        | #{t('blog.updated_at')}:
        = article.updated_at&.strftime('%Y年%m月%d日')

      - if article.translation.present?
        p= link_to "#{article.locale == 'ja' ? 'English' : '日本語'}版", user_article_path(article.translation.user.username, article.translation.id, locale: article.translation.locale)

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
    = link_to "すべてクリア", user_articles_path(params[:username], locale: params[:locale])

/ レイアウト判定とコンテンツ表示
- case @blog_setting&.layout_style || 'linear'
- when 'linear'
  = render 'linear_layout', articles: @articles, filter: @filter

- when 'hero_tiles'
  = render 'hero_tiles_layout', articles: @articles, filter: @filter, blog_setting: @blog_setting

- when 'hero_list'
  = render 'hero_list_layout', articles: @articles, filter: @filter, blog_setting: @blog_setting

/ ページネーション
= paginate @articles

/ 記事一覧
/- @articles.each do |article|
/  .article-item.mb-8.p-6.border-b.border-gray-500
/    .article-header.max-w-3xl.mx-auto
/      h2.text-4xl.font-extrabold.mb-4.mt-8.text-gray-900.border-b.border-gray-500.pb-2
/        = link_to article.title, user_article_path(article.user.username, article.id, locale: params[:locale])
/
/      .article-meta.pb-3.mb-4
/        - if article.category.present?
/          p.pb-2
/            | #{t('blog.category')}:
/            = link_to article.category.name, user_articles_path(params[:username], @filter.filter_params.merge(category_id: article.category.id))
/
/        = render 'shared/article_tags', article: article, filter_params: @filter.filter_params
/
/      .meta-content-divider.text-center.mx-8
/        span.text-gray-400.text-xl • • •
/
/    .article-content.medium-container style="all: revert;"
/      div class="medium"
/        = article.content_html
/
/    .article-meta.max-w-3xl.mx-auto.text-right
/      p
/        | #{t('blog.published_at')}:
/        = article.published_at&.strftime('%Y年%m月%d日')
/      p
/        | #{t('blog.updated_at')}:
/        = article.updated_at&.strftime('%Y年%m月%d日')
/
/      - if article.translation.present?
/        p= link_to "#{article.locale == 'ja' ? 'English' : '日本語'}版", user_article_path(article.translation.user.username, article.translation.id, locale: article.translation.locale)
/
/= paginate @articles
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
        = t('blog.published_at')
      span.w-4.text-gray-500.text-center
        | :
      span.text-gray-500
        = @article.published_at&.strftime('%Y年%m月%d日')

    .flex.items-center.mb-2
      span.w-20.text-gray-500.text-right
        = t('blog.updated_at')
      span.w-4.text-gray-500.text-center
        | :
      span.text-gray-500
        = @article.updated_at&.strftime('%Y年%m月%d日')

    .flex.items-center.mb-2
      - if @article.category.present?
        span.w-20.text-gray-500.text-right
          = t('blog.category')
        span.w-4.text-gray-500.text-center
          | :
        span.text-gray-500.hover:text-gray-800
          = link_to @article.category.name, user_articles_path(locale: params[:locale], category_id: @article.category.id)

    .flex.items-center.mb-2
      span.w-20.text-gray-500.text-right
        = t('blog.tags')
      span.w-4.text-gray-500.text-center
        | :
      span
        = render 'shared/article_tags', article: @article, filter_params: {}

    - if @article.translation.present?
      .flex.items-center.mb-2
        span.w-20.text-gray-500.text-right
          = t('blog.translation')
        span.w-4.text-gray-500.text-center
          | :
        span
          = link_to "#{@article.locale == 'ja' ? 'English' : '日本語'}版", user_article_path(@article.translation.user.username, @article.translation.id, locale: @article.translation.locale), class: "pb-2 block text-gray-500 hover:text-gray-800"


  - if @blog_setting&.show_hero_thumbnail && has_cover_image?(@article)
    .hero-thumbnail.max-w-5xl.mx-auto.mb-6
      = image_tag thumbnail_for_article(@article, @blog_setting), class: "w-full h-64 object-cover rounded-lg shadow-md"

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
            = t('comments.number', number: index)
          .mb-2
            - if comment.website.present?
              = link_to comment.author_name, comment.website, target: "_blank"
            - else
              = comment.author_name
          p.text-sm.text-gray-500.mb-2= comment.created_at.strftime('%Y年%m月%d日 %H:%M')
          .text-gray-700= simple_format(comment.content)
    - else
      p= t('comments.none')

  .comment-form.max-w-5xl.mx-auto.py-8
    = form_with model: Comment.new, url: user_article_comments_path(@article.user.username, @article.id), local: true do |f|
      .flex.flex-col.w-1/2.mb-2
        = f.label :author_name, "#{t('comments.author_name')}:", class: "mb-2"
        = f.text_field :author_name, required: true, class: "border-0 border-b border-gray-600 focus:outline-none"
      .flex.flex-col.w-1/2.mb-2
        = f.label :website, "#{t('comments.website')}:", class: "mb-2"
        = f.url_field :website, class: "border-0 border-b border-gray-600 focus:outline-none"
      .flex.flex-col.w-1/2.mb-2
        = f.label :content, "#{t('comments.content')}:", class: "mb-2"
        = f.text_area :content, rows: 5, required: true, class: "border border-gray-600 focus:outline-none"
      
      = f.submit t('comments.submit'), class: "px-4 py-2 border border-gray-300 bg-white cursor-pointer text-base rounded hover:bg-gray-200 transition-colors"
```

## File: `app/views/comments/new.html.slim`

```
h1 Comments#new
p Find me in app/views/comments/new.html.slim
```

## File: `app/views/contact_mailer/new_contact.html.slim`

```
p
  strong お名前: 
  = @contact.name
p
  strong メールアドレス: 
  = @contact.email
p
  strong 件名: 
  = @contact.subject

h3 メッセージ:
p= simple_format(@contact.message)

hr
p
  small 
    | 送信日時:
    = @contact.created_at.strftime('%Y年%m月%d日 %H:%M')
```

## File: `app/views/contact_mailer/new_contact.text.erb`

```
お名前: <%= @contact.name %>
メールアドレス: <%= @contact.email %>
件名: <%= @contact.subject %>

メッセージ:
<%= @contact.message %>

送信日時: <%= @contact.created_at.strftime('%Y年%m月%d日 %H:%M') %>
```

## File: `app/views/contacts/create.html.slim`

```
h1 Contacts#create
p Find me in app/views/contacts/create.html.slim
```

## File: `app/views/contacts/new.html.slim`

```
.max-w-2xl.mx-auto.py-8
  h1.text-3xl.font-bold.mb-6 運営への問い合わせ

  .bg-blue-50.border.border-blue-200.rounded-md.p-4.mb-6
    p.text-blue-800.text-sm
      | このお問い合わせは Dual Pascal（ブログプラットフォーム）の運営に関するものです。
      br
      | 個別のブログ記事や著者への連絡は、各記事のコメント欄または著者のプロフィールページをご利用ください。

  .bg-white.rounded-lg.border.border-gray-200.shadow-sm.p-6
    - if @contact.errors.any?
      .bg-red-50.border.border-red-200.rounded-md.p-4.mb-6
        h4.text-red-800.font-semibold エラーが発生しました:
        ul.mt-2.text-red-700
          - @contact.errors.full_messages.each do |message|
            li.text-sm= message

    = form_with model: @contact, local: true, class: "space-y-6" do |f|
      div
        = f.label :name, "お名前", class: "block text-sm font-medium text-gray-700 mb-2"
        = f.text_field :name, required: true, class: "w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-1 focus:ring-blue-500"

      div
        = f.label :email, "メールアドレス", class: "block text-sm font-medium text-gray-700 mb-2"
        = f.email_field :email, required: true, class: "w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-1 focus:ring-blue-500"

      div
        = f.label :subject, "件名", class: "block text-sm font-medium text-gray-700 mb-2"
        = f.text_field :subject, required: true, class: "w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-1 focus:ring-blue-500"

      div
        = f.label :message, "お問い合わせ内容", class: "block text-sm font-medium text-gray-700 mb-2"
        = f.text_area :message, rows: 6, required: true, class: "w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-1 focus:ring-blue-500"

      .flex.gap-3
        = f.submit "送信", class: "bg-blue-500 hover:bg-blue-600 text-white px-6 py-2 rounded-md transition-colors"
        = link_to "キャンセル", root_path, class: "bg-gray-500 hover:bg-gray-600 text-white px-6 py-2 rounded-md transition-colors"
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

    = link_to "📥", dashboard_article_export_path(article_data, locale: params[:locale]), class: "text-gray-600 hover:text-gray-800", title: "記事をエクスポート"

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

div data-controller="markdown-preview image-upload layout-switcher category-modal" data-markdown-preview-url-value=dashboard_preview_path(locale: params[:locale]) data-layout-switcher-translation-mode-value=is_translation data-category-modal-url-value="#{dashboard_categories_path(format: :json)}" data-category-modal-locale-value="#{article.locale || 'ja'}" class="layout-switcher"

  div data-layout-switcher-target="buttons" class="layout-buttons flex gap-1 justify-center mb-2"
    button.layout-button type="button" data-action="click->layout-switcher#switchToSplit" data-mode="split" ⚏
    button.layout-button type="button" data-action="click->layout-switcher#switchToTextOnly" data-mode="text-only" ☰
    button.layout-button type="button" data-action="click->layout-switcher#switchToPreviewOnly" data-mode="preview-only" ⚇
    - if is_translation
      button.layout-button type="button" data-action="click->layout-switcher#switchToOriginalPreview" data-mode="original-preview" 原

  div class= "relative flex gap-5 h-screen"
    div data-layout-switcher-target="textArea" class="flex-1 pr-5 flex flex-col h-full text-area"

      = form_with model: article, url: form_url, local: true do |f|

        div class="flex items-baseline mb-6 border-b border-gray-400"

          div class="flex items-baseline gap-4"
            p
              = f.select :locale, options_for_select([["日本語", "ja"], ["English", "en"]], article.locale), {}, { disabled: locale_disabled, class: "text-gray-600 border border-gray-400 rounded" }
            p
              = f.select :status, options_for_select([["下書き", "draft"],["公開", "published"]], article.status), {}, class: "text-gray-600 border border-gray-400 rounded"

          div class="flex items-baseline gap-1 mx-4"
            /label for="cover_image_input" class="btn-unified cursor-pointer text-xs"
            label for="cover_image_input" class="cursor-pointer" title="カバー画像"
              | 🖼️
            = f.file_field :cover_image, accept: "image/*", class: "hidden", id: "cover_image_input"
    
            - case button_type
            - when "new"
              = f.submit "🌐", class: "cursor-pointer", title: "投稿"
            - when "edit"
              = f.submit "🔄", class: "cursor-pointer", title: "更新"
              = link_to "✖️", dashboard_articles_path, class: "cursor-pointer", title: "キャンセル"
              = link_to "🗑️", dashboard_article_path(article), class: "cursor-pointer",title: "削除" , data: { "turbo-method": "delete", "turbo-confirm": "本当に削除しますか？" }
            - when "translation"
              = f.submit "🌐", class: "cursor-pointer", title: "翻訳"
              = link_to "✖️", dashboard_article_path(original_article), class: "cursor-pointer", title: "キャンセル"

        div class="ml-auto flex gap-2 border-b border-gray-400"
          .flex.items-center.gap-1
            button.text-gray-500.hover:text-gray-700.text-lg.font-bold type="button" data-action="click->category-modal#showModal" title="新しいカテゴリを追加" +
            = f.select :category_id, options_from_collection_for_select(@categories, :id, :name, article.category_id), { prompt: "---" }, { class: "text-gray-400 focus:outline-none", required: false, data: { category_modal_target: "select" } }
          p
            = f.text_field :tag_list, placeholder: "tags", class: "text-gray-600 focus:outline-none"
          p
            button type="button" data-action="click->image-upload#selectImage" class="cursor-pointer mb-2 text-gray-400 text-sm"
              /| 📷
              | 画像を挿入
        p
          = f.text_field :title, required: true,
            class: "w-full border-b border-gray-400 placeholder-gray-400 p-2 focus:border-gray-400 focus:outline-none mb-3",
            placeholder: "title",
            data: { field: "title", action: "input->markdown-preview#preview" }
            
          = f.text_area :content, required: true, style: "width: 100%; padding-bottom: 36rem;", data: { markdown_preview_target: "input", action: "input->markdown-preview#preview", image_upload_target: "textarea" }, class: "px-3 py-2 border-0 focus:ring-0 focus:outline-none focus:border-[1px] focus:border-gray-300"

    .fixed.inset-0.bg-black.bg-opacity-50.flex.items-center.justify-center.z-50.hidden data-category-modal-target="modal"
      .bg-white.rounded-lg.p-6.w-96.max-w-90vw
        h3.text-lg.font-semibold.mb-4 新しいカテゴリを作成

        form data-category-modal-target="form" data-action="submit->category-modal#submitForm"
          .mb-4
            label.block.text-sm.font-medium.text-gray-700.mb-2 カテゴリ名
            input.w-full.border.border-gray-300.rounded-md.px-3.py-2.focus:outline-none.focus:ring-1.focus:ring-gray-500 type="text" name="category[name]" required="" placeholder="カテゴリ名を入力"
          .flex.gap-3.justify-end
            button.px-4.py-2.text-gray-600.border.border-gray-300.rounded-md.hover:bg-gray-50 type="button" data-action="click->category-modal#closeModal" キャンセル
            button.px-4.py-2.bg-blue-500.text-white.rounded-md.hover:bg-blue-600 type="submit" 作成

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
      = f.label :blog_title_ja, "ブログタイトル", class: "block text-sm font-medium text-gray-700 mb-2"
      .grid.grid-cols-1.gap-4
        div
          = f.label :blog_title_ja, "日本語", class: "block text-xs text-gray-500 mb-1"
          = f.text_field :blog_title_ja, class: "w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-1 focus:ring-blue-500", placeholder: "私のブログ"
        div
          = f.label :blog_title_en, "English", class: "block text-xs text-gray-500 mb-1"
          = f.text_field :blog_title_en, class: "w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-1 focus:ring-blue-500", placeholder: "My Blog"
    
    div
      = f.label :blog_subtitle_ja, "サブタイトル", class: "block text-sm font-medium text-gray-700 mb-2"
      .grid.grid-cols-1.gap-4
        div
          = f.label :blog_subtitle_ja, "日本語", class: "block text-xs text-gray-500 mb-1"
          = f.text_field :blog_subtitle_ja, class: "w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-1 focus:ring-blue-500", placeholder: "素晴らしいブログの説明"
        div
          = f.label :blog_subtitle_en, "English", class: "block text-xs text-gray-500 mb-1"
          = f.text_field :blog_subtitle_en, class: "w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-1 focus:ring-blue-500", placeholder: "An amazing blog description"
    
    div data-controller="theme"
      = f.label :theme_color, "テーマカラー", class: "block text-sm font-medium text-gray-700 mb-2"
      .flex.space-x-2
        - { default: "#ffffff", slate: "#0a1a2f", forest: "#1b4332", maroon: "#3a0a0a", midnight: "#222b45" }.each do |key, color|
          .relative
            = f.radio_button :theme_color, key, id: "theme_#{key}", class: "sr-only peer", data: { action: "change->theme#changeTheme" }
            label for="theme_#{key}" class="flex flex-col items-center cursor-pointer"
              - if key == :default
                .w-6.h-6.rounded-full.border.border-gray-300.bg-white style="box-shadow: inset 0 0 0 1px #d1d5db;"
              - else
                .w-6.h-6.rounded-full.border.border-gray-300 style="background-color: #{color};"
            .absolute.inset-0.rounded-full.pointer-events-none.peer-checked:ring-2.peer-checked:ring-blue-400
          span.text-xs.text-gray-600= key.to_s

    div data-controller="layout-preview"
      = f.label :layout_style, "記事一覧レイアウト", class: "block text-sm font-medium text-gray-700 mb-2"
      .space-y-3
        .flex.items-center
          = f.radio_button :layout_style, "linear", id: "layout_linear", class: "mr-2"
          label for="layout_linear" class="flex items-center cursor-pointer"
            .layout-preview-box.mr-3 style="width: 60px; height: 40px; border: 1px solid #d1d5db; display: flex; flex-direction: column; gap: 2px; padding: 4px;"
              .bg-gray-300 style="height: 6px; width: 100%;"
              .bg-gray-200 style="height: 4px; width: 80%;"
              .bg-gray-300 style="height: 6px; width: 100%;"
              .bg-gray-200 style="height: 4px; width: 80%;"
            span.text-sm リニア表示
        
        .flex.items-center
          = f.radio_button :layout_style, "hero_tiles", id: "layout_hero_tiles", class: "mr-2"
          label for="layout_hero_tiles" class="flex items-center cursor-pointer"
            .layout-preview-box.mr-3 style="width: 60px; height: 40px; border: 1px solid #d1d5db; display: flex; flex-direction: column; gap: 1px; padding: 4px;"
              .bg-blue-300 style="height: 12px; width: 100%;"
              .flex.gap-1 style="height: 24px;"
                .bg-gray-300 style="width: 32%; height: 100%;"
                .bg-gray-300 style="width: 32%; height: 100%;"
                .bg-gray-300 style="width: 32%; height: 100%;"
            span.text-sm ヒーロー＋タイル表示
        
        .flex.items-center
          = f.radio_button :layout_style, "hero_list", id: "layout_hero_list", class: "mr-2"
          label for="layout_hero_list" class="flex items-center cursor-pointer"
            .layout-preview-box.mr-3 style="width: 60px; height: 40px; border: 1px solid #d1d5db; display: flex; flex-direction: column; gap: 1px; padding: 4px;"
              .bg-blue-300 style="height: 12px; width: 100%;"
              .bg-gray-200 style="height: 3px; width: 90%;"
              .bg-gray-200 style="height: 3px; width: 90%;"
              .bg-gray-200 style="height: 3px; width: 90%;"
              .bg-gray-200 style="height: 3px; width: 90%;"
            span.text-sm ヒーロー＋リスト表示


        div
          = f.label :show_hero_thumbnail, "ヒーロー記事のサムネイル表示", class: "block text-sm font-medium text-gray-700 mb-2"
          .flex.items-center
            = f.check_box :show_hero_thumbnail, class: "mr-2"
            = f.label :show_hero_thumbnail, "ヒーロー記事にサムネイル画像を表示する", class: "text-sm text-gray-600"



    .flex.gap-3
      = f.submit "設定を保存", class: "bg-blue-500 hover:bg-blue-600 text-white px-6 py-2 rounded-md transition-colors"
      = link_to "キャンセル", dashboard_articles_path, class: "bg-gray-500 hover:bg-gray-600 text-white px-6 py-2 rounded-md transition-colors"
```

## File: `app/views/dashboard/categories/_category_table.html.slim`

```
- if categories.any?
  table.w-full
    thead.bg-gray-50
      tr
        th.px-6.py-3.text-left.text-xs.font-medium.text-gray-500.uppercase.tracking-wider ID
        th.px-6.py-3.text-left.text-xs.font-medium.text-gray-500.uppercase.tracking-wider カテゴリ名
        th.px-6.py-3.text-left.text-xs.font-medium.text-gray-500.uppercase.tracking-wider 説明
        th.px-6.py-3.text-left.text-xs.font-medium.text-gray-500.uppercase.tracking-wider 記事数
        th.px-6.py-3.text-left.text-xs.font-medium.text-gray-500.uppercase.tracking-wider アクション
    tbody.bg-white.divide-y.divide-gray-200
      - categories.each_with_index do |category, index|
        tr class="#{index.even? ? 'bg-white' : 'bg-gray-50'}"
          td.px-6.py-4.whitespace-nowrap.text-sm.text-gray-900= category.id
          td.px-6.py-4.whitespace-nowrap.text-sm.font-medium.text-gray-900= category.name
          td.px-6.py-4.text-sm.text-gray-500
            = truncate(category.description, length: 50) if category.description.present?
          td.px-6.py-4.whitespace-nowrap.text-sm.text-gray-900= category.articles_count || 0
          td.px-6.py-4.whitespace-nowrap.text-sm.font-medium
            .flex.gap-2
              = link_to "編集", edit_dashboard_category_path(category), class: "btn-unified text-sm"
              = link_to "削除", dashboard_category_path(category), data: { turbo_method: :delete, turbo_confirm: "削除しますか？" }, class: "btn-unified text-sm"
- else
  .p-8.text-center
    p.text-gray-500.text-lg カテゴリがありません
```

## File: `app/views/dashboard/categories/edit.html.slim`

```
h1.text-2xl.font-bold.mb-6 カテゴリを編集

- if @category.errors.any?
  .bg-red-50.border.border-red-200.rounded-md.p-4.mb-6
    h4.text-red-800.font-semibold エラーが発生しました:
    ul.mt-2.text-red-700
      - @category.errors.full_messages.each do |message|
        li.text-sm= message

.bg-white.rounded-lg.border.border-gray-200.shadow-sm.p-6
  = form_with model: [:dashboard, @category], local: true, class: "space-y-6" do |f|
    div
      = f.label :name, "カテゴリ名", class: "block text-sm font-medium text-gray-700 mb-2"
      = f.text_field :name, required: true, class: "w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-1 focus:ring-blue-500"

    div
      = f.label :description, "説明(任意)", class: "block text-sm font-medium text-gray-700 mb-2"
      = f.text_area :description, rows: 4, class: "w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-1 focus:ring-blue-500"

    div
      = f.label :locale, "言語", class: "block text-sm font-medium text-gray-700 mb-2"
      = f.select :locale, options_for_select([["日本語", "ja"], ["English", "en"]], @category.locale), {}, { disabled: true, class: "w-full border border-gray-300 rounded-md px-3 py-2 bg-gray-50 text-gray-500" }
      small.block.text-gray-500.text-sm.mt-1
        | 言語は変更できません

    .flex.gap-3
      = f.submit "カテゴリを更新", class: "btn-unified"
      = link_to "キャンセル", dashboard_categories_path, class: "btn-unified"
      = link_to "削除", dashboard_category_path(@category), data: { turbo_method: :delete, turbo_confirm: "このカテゴリを削除しますか？" }, class: "btn-unified"
```

## File: `app/views/dashboard/categories/index.html.slim`

```
h1.text-2xl.font-bold.mb-6 カテゴリ管理

.tab-container data-controller="category-tabs"
  .tab-buttons.mb-6
    button.tab-button.active data-action="click->category-tabs#switchTab" data-target="ja" data-category-tabs-target="button"
      | 日本語 (#{category_count_for_locale("ja")})
    button.tab-button data-action="click->category-tabs#switchTab" data-target="en" data-category-tabs-target="button"
      | English (#{category_count_for_locale("en")})

  .tab-content.active data-category-tabs-target="content" data-tab="ja"
    .mb-6
      = link_to "日本語カテゴリを作成", new_dashboard_category_path(locale: "ja"), class: "btn-unified"
    .bg-white.rounded-lg.border.border-gray-200.shadow-sm.overflow-hidden
      = render "category_table", categories: @ja_categories

  .tab-content data-category-tabs-target="content" data-tab="en"
    .mb-6
      = link_to "英語カテゴリを作成", new_dashboard_category_path(locale: "en"), class: "btn-unified"
    .bg-white.rounded-lg.border.border-gray-200.shadow-sm.overflow-hidden
      = render "category_table", categories: @en_categories
```

## File: `app/views/dashboard/categories/new.html.slim`

```
h1.text-2xl.font-bold.mb-6 新しいカテゴリを作成

- if @category.errors.any?
  .bg-red-50.border.border-red-200.rounded-md.p-4.mb-6
    h4.text-red-800.font-semibold エラーが発生しました:
    ul.mt-2.text-red-700
      - @category.errors.full_messages.each do |message|
        li.text-sm= message

.bg-white.rounded-lg.border.border-gray-200.shadow-sm.p-6
  = form_with model: [:dashboard, @category], local: true, class: "space-y-6" do |f|
    div
      = f.label :name, "カテゴリ名", class: "block text-sm font-medium text-gray-700 mb-2"
      = f.text_field :name, required: true, class: "w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-1 focus:ring-blue-500"

    div
      = f.label :description, "説明(任意)", class: "block text-sm font-medium text-gray-700 mb-2"
      = f.text_area :description, rows: 4, class: "w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-1 focus:ring-blue-500"

    div
      = f.label :locale, "言語", class: "block text-sm font-medium text-gray-700 mb-2"
      = f.select :locale, options_for_select([["日本語", "ja"], ["English", "en"]], @category.locale), {}, { disabled: true, class: "w-full border border-gray-300 rounded-md px-3 py-2 bg-gray-50 text-gray-500" }
      small.block.text-gray-500.text-sm.mt-1
        | 言語は作成時に決定され、後から変更できません

    .flex.gap-3
      = f.submit "カテゴリを作成", class: "btn-unified"
      = link_to "キャンセル", dashboard_categories_path, class: "btn-unified"
```

## File: `app/views/dashboard/comments/index.html.slim`

```
h1.text-2xl.font-bold.mb-6 コメント管理

.bg-white.rounded-lg.border.border-gray-200.shadow-sm.overflow-hidden
  - if @comments.any?
    table.w-full
      thead.bg-gray-50
        tr
          th.px-6.py-3.text-left.text-xs.font-medium.text-gray-500.uppercase.tracking-wider 記事タイトル
          th.px-6.py-3.text-left.text-xs.font-medium.text-gray-500.uppercase.tracking-wider コメント者
          th.px-6.py-3.text-left.text-xs.font-medium.text-gray-500.uppercase.tracking-wider コメント内容(抜粋)
          th.px-6.py-3.text-left.text-xs.font-medium.text-gray-500.uppercase.tracking-wider 投稿日
          th.px-6.py-3.text-left.text-xs.font-medium.text-gray-500.uppercase.tracking-wider アクション
      tbody.bg-white.divide-y.divide-gray-200
        - @comments.each_with_index do |comment, index|
          tr class="#{index.even? ? 'bg-white' : 'bg-gray-50'}"
            td.px-6.py-4.text-sm.text-gray-900
              = link_to comment.article.title, user_article_path(comment.article.user.username, comment.article.id, locale: comment.article.locale), class: "text-blue-600 hover:text-blue-800 font-medium", target: "_blank"
            td.px-6.py-4.whitespace-nowrap.text-sm.font-medium.text-gray-900= comment.author_name
            td.px-6.py-4.text-sm.text-gray-500.max-w-xs
              .truncate= truncate(comment.content, length: 50)
            td.px-6.py-4.whitespace-nowrap.text-sm.text-gray-500= comment.created_at.strftime('%Y/%m/%d %H:%M')
            td.px-6.py-4.whitespace-nowrap.text-sm.font-medium
              .flex.gap-2
                = link_to "詳細", dashboard_comment_path(comment, locale: params[:locale]), class: "btn-unified text-sm"
                = link_to "削除", dashboard_comment_path(comment, locale: params[:locale]), data: { turbo_method: :delete, turbo_confirm: "削除しますか？" }, class: "btn-unified text-sm"
  - else
    .p-8.text-center
      p.text-gray-500.text-lg コメントはまだありません

- if @comments.respond_to?(:current_page)
  .px-6.py-4.bg-gray-50.border-t.border-gray-200
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
    
    .grid.grid-cols-1.md:grid-cols-2.gap-4
      div
        = f.label :twitter_handle, "X (Twitter)", class: "block text-sm font-medium text-gray-700 mb-2"
        = f.text_field :twitter_handle, placeholder: "@username", class: "w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-1 focus:ring-blue-500"
      
      div
        = f.label :facebook_handle, "Facebook", class: "block text-sm font-medium text-gray-700 mb-2"
        = f.text_field :facebook_handle, placeholder: "username", class: "w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-1 focus:ring-blue-500"
      
      div
        = f.label :linkedin_handle, "LinkedIn", class: "block text-sm font-medium text-gray-700 mb-2"
        = f.text_field :linkedin_handle, placeholder: "username", class: "w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-1 focus:ring-blue-500"

      div
        = f.label :github_handle, "GitHub", class: "block text-sm font-medium text-gray-700 mb-2"
        = f.text_field :github_handle, placeholder: "username", class: "w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-1 focus:ring-blue-500"
     
      div
        = f.label :qiita_handle, "Qiita", class: "block text-sm font-medium text-gray-700 mb-2"
        = f.text_field :qiita_handle, placeholder: "username", class: "w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-1 focus:ring-blue-500"
     
      div
        = f.label :zenn_handle, "Zenn", class: "block text-sm font-medium text-gray-700 mb-2"
        = f.text_field :zenn_handle, placeholder: "username", class: "w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-1 focus:ring-blue-500"
     
      div
        = f.label :hatena_handle, "はてなブログ", class: "block text-sm font-medium text-gray-700 mb-2"
        = f.text_field :hatena_handle, placeholder: "username", class: "w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-1 focus:ring-blue-500"

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

## File: `app/views/devise/confirmations/new.html.erb`

```
<h2>Resend confirmation instructions</h2>

<%= form_for(resource, as: resource_name, url: confirmation_path(resource_name), html: { method: :post }) do |f| %>
  <%= render "devise/shared/error_messages", resource: resource %>

  <div class="field">
    <%= f.label :email %><br />
    <%= f.email_field :email, autofocus: true, autocomplete: "email", value: (resource.pending_reconfirmation? ? resource.unconfirmed_email : resource.email) %>
  </div>

  <div class="actions">
    <%= f.submit "Resend confirmation instructions" %>
  </div>
<% end %>

<%= render "devise/shared/links" %>
```

## File: `app/views/devise/mailer/confirmation_instructions.html.erb`

```
<p>Welcome <%= @email %>!</p>

<p>You can confirm your account email through the link below:</p>

<p><%= link_to 'Confirm my account', confirmation_url(@resource, confirmation_token: @token) %></p>
```

## File: `app/views/devise/mailer/email_changed.html.erb`

```
<p>Hello <%= @email %>!</p>

<% if @resource.try(:unconfirmed_email?) %>
  <p>We're contacting you to notify you that your email is being changed to <%= @resource.unconfirmed_email %>.</p>
<% else %>
  <p>We're contacting you to notify you that your email has been changed to <%= @resource.email %>.</p>
<% end %>
```

## File: `app/views/devise/mailer/password_change.html.erb`

```
<p>Hello <%= @resource.email %>!</p>

<p>We're contacting you to notify you that your password has been changed.</p>
```

## File: `app/views/devise/mailer/reset_password_instructions.html.erb`

```
<p>Hello <%= @resource.email %>!</p>

<p>Someone has requested a link to change your password. You can do this through the link below.</p>

<p><%= link_to 'Change my password', edit_password_url(@resource, reset_password_token: @token) %></p>

<p>If you didn't request this, please ignore this email.</p>
<p>Your password won't change until you access the link above and create a new one.</p>
```

## File: `app/views/devise/mailer/unlock_instructions.html.erb`

```
<p>Hello <%= @resource.email %>!</p>

<p>Your account has been locked due to an excessive number of unsuccessful sign in attempts.</p>

<p>Click the link below to unlock your account:</p>

<p><%= link_to 'Unlock my account', unlock_url(@resource, unlock_token: @token) %></p>
```

## File: `app/views/devise/passwords/edit.html.erb`

```
<h2>Change your password</h2>

<%= form_for(resource, as: resource_name, url: password_path(resource_name), html: { method: :put }) do |f| %>
  <%= render "devise/shared/error_messages", resource: resource %>
  <%= f.hidden_field :reset_password_token %>

  <div class="field">
    <%= f.label :password, "New password" %><br />
    <% if @minimum_password_length %>
      <em>(<%= @minimum_password_length %> characters minimum)</em><br />
    <% end %>
    <%= f.password_field :password, autofocus: true, autocomplete: "new-password" %>
  </div>

  <div class="field">
    <%= f.label :password_confirmation, "Confirm new password" %><br />
    <%= f.password_field :password_confirmation, autocomplete: "new-password" %>
  </div>

  <div class="actions">
    <%= f.submit "Change my password" %>
  </div>
<% end %>

<%= render "devise/shared/links" %>
```

## File: `app/views/devise/passwords/new.html.erb`

```
<h2>Forgot your password?</h2>

<%= form_for(resource, as: resource_name, url: password_path(resource_name), html: { method: :post }) do |f| %>
  <%= render "devise/shared/error_messages", resource: resource %>

  <div class="field">
    <%= f.label :email %><br />
    <%= f.email_field :email, autofocus: true, autocomplete: "email" %>
  </div>

  <div class="actions">
    <%= f.submit "Send me reset password instructions" %>
  </div>
<% end %>

<%= render "devise/shared/links" %>
```

## File: `app/views/devise/registrations/edit.html.erb`

```
<h2>Edit <%= resource_name.to_s.humanize %></h2>

<%= form_for(resource, as: resource_name, url: registration_path(resource_name), html: { method: :put }) do |f| %>
  <%= render "devise/shared/error_messages", resource: resource %>

  <div class="field">
    <%= f.label :email %><br />
    <%= f.email_field :email, autofocus: true, autocomplete: "email" %>
  </div>

  <% if devise_mapping.confirmable? && resource.pending_reconfirmation? %>
    <div>Currently waiting confirmation for: <%= resource.unconfirmed_email %></div>
  <% end %>

  <div class="field">
    <%= f.label :password %> <i>(leave blank if you don't want to change it)</i><br />
    <%= f.password_field :password, autocomplete: "new-password" %>
    <% if @minimum_password_length %>
      <br />
      <em><%= @minimum_password_length %> characters minimum</em>
    <% end %>
  </div>

  <div class="field">
    <%= f.label :password_confirmation %><br />
    <%= f.password_field :password_confirmation, autocomplete: "new-password" %>
  </div>

  <div class="field">
    <%= f.label :current_password %> <i>(we need your current password to confirm your changes)</i><br />
    <%= f.password_field :current_password, autocomplete: "current-password" %>
  </div>

  <div class="actions">
    <%= f.submit "Update" %>
  </div>
<% end %>

<h3>Cancel my account</h3>

<div>Unhappy? <%= button_to "Cancel my account", registration_path(resource_name), data: { confirm: "Are you sure?", turbo_confirm: "Are you sure?" }, method: :delete %></div>

<%= link_to "Back", :back %>
```

## File: `app/views/devise/registrations/new.html.erb`

```
<h2>Sign up</h2>

<%= form_for(resource, as: resource_name, url: registration_path(resource_name)) do |f| %>
  <%= render "devise/shared/error_messages", resource: resource %>

  <div class="field">
    <%= f.label :username %><br />
    <%= f.text_field :username, autofocus: true %>
  </div>

  <div class="field">
    <%= f.label :email %><br />
    <%= f.email_field :email, autofocus: true, autocomplete: "email" %>
  </div>

  <div class="field">
    <%= f.label :password %>
    <% if @minimum_password_length %>
    <em>(<%= @minimum_password_length %> characters minimum)</em>
    <% end %><br />
    <%= f.password_field :password, autocomplete: "new-password" %>
  </div>

  <div class="field">
    <%= f.label :password_confirmation %><br />
    <%= f.password_field :password_confirmation, autocomplete: "new-password" %>
  </div>

  <div class="actions">
    <%= f.submit "Sign up" %>
  </div>
<% end %>

<%= render "devise/shared/links" %>
```

## File: `app/views/devise/sessions/new.html.erb`

```
<h2>Log in</h2>

<%= form_for(resource, as: resource_name, url: session_path(resource_name)) do |f| %>
  <div class="field">
    <%= f.label :email %><br />
    <%= f.email_field :email, autofocus: true, autocomplete: "email" %>
  </div>

  <div class="field">
    <%= f.label :password %><br />
    <%= f.password_field :password, autocomplete: "current-password" %>
  </div>

  <% if devise_mapping.rememberable? %>
    <div class="field">
      <%= f.check_box :remember_me %>
      <%= f.label :remember_me %>
    </div>
  <% end %>

  <div class="actions">
    <%= f.submit "Log in" %>
  </div>
<% end %>

<%= render "devise/shared/links" %>
```

## File: `app/views/devise/shared/_error_messages.html.erb`

```
<% if resource.errors.any? %>
  <div id="error_explanation" data-turbo-cache="false">
    <h2>
      <%= I18n.t("errors.messages.not_saved",
                 count: resource.errors.count,
                 resource: resource.class.model_name.human.downcase)
       %>
    </h2>
    <ul>
      <% resource.errors.full_messages.each do |message| %>
        <li><%= message %></li>
      <% end %>
    </ul>
  </div>
<% end %>
```

## File: `app/views/devise/shared/_links.html.erb`

```
<%- if controller_name != 'sessions' %>
  <%= link_to "Log in", new_session_path(resource_name) %><br />
<% end %>

<%- if devise_mapping.registerable? && controller_name != 'registrations' %>
  <%= link_to "Sign up", new_registration_path(resource_name) %><br />
<% end %>

<%- if devise_mapping.recoverable? && controller_name != 'passwords' && controller_name != 'registrations' %>
  <%= link_to "Forgot your password?", new_password_path(resource_name) %><br />
<% end %>

<%- if devise_mapping.confirmable? && controller_name != 'confirmations' %>
  <%= link_to "Didn't receive confirmation instructions?", new_confirmation_path(resource_name) %><br />
<% end %>

<%- if devise_mapping.lockable? && resource_class.unlock_strategy_enabled?(:email) && controller_name != 'unlocks' %>
  <%= link_to "Didn't receive unlock instructions?", new_unlock_path(resource_name) %><br />
<% end %>

<%- if devise_mapping.omniauthable? %>
  <%- resource_class.omniauth_providers.each do |provider| %>
    <%= button_to "Sign in with #{OmniAuth::Utils.camelize(provider)}", omniauth_authorize_path(resource_name, provider), data: { turbo: false } %><br />
  <% end %>
<% end %>
```

## File: `app/views/devise/unlocks/new.html.erb`

```
<h2>Resend unlock instructions</h2>

<%= form_for(resource, as: resource_name, url: unlock_path(resource_name), html: { method: :post }) do |f| %>
  <%= render "devise/shared/error_messages", resource: resource %>

  <div class="field">
    <%= f.label :email %><br />
    <%= f.email_field :email, autofocus: true, autocomplete: "email" %>
  </div>

  <div class="actions">
    <%= f.submit "Resend unlock instructions" %>
  </div>
<% end %>

<%= render "devise/shared/links" %>
```

## File: `app/views/layouts/admin.html.erb`

```
<!DOCTYPE html>
<html class="default-theme">
  <head>
    <title>Dual Pascal - 管理画面</title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>
    <%= stylesheet_link_tag :app, "data-turbo-track": "reload" %>
    <%= javascript_importmap_tags %>
  </head>
  <body class="text-lg bg-gray-50 min-h-screen flex flex-col">
    <!-- 管理画面ヘッダー -->
    <header class="bg-gray-800 text-white">
      <div class="max-w-6xl mx-auto px-6 py-4">
        <div class="flex justify-between items-center">
          <h1 class="text-xl font-bold">Dual Pascal 管理画面</h1>
          <nav class="flex gap-4">
            <%= link_to "ダッシュボード", admin_root_path, class: "hover:text-gray-300" %>
            <%= link_to "ユーザー", admin_users_path, class: "hover:text-gray-300" %>
            <%= link_to "記事", admin_articles_path, class: "hover:text-gray-300" %>
            <%= link_to "問い合わせ", admin_contacts_path, class: "hover:text-gray-300" %>
            <span class="text-gray-400">|</span>
            <%= link_to "サイトに戻る", root_path, class: "hover:text-gray-300" %>
            <%= link_to "ログアウト", destroy_user_session_path, data: { "turbo-method": "delete" }, class: "hover:text-gray-300" %>
          </nav>
        </div>
      </div>
    </header>

    <!-- フラッシュメッセージ -->
    <% flash.each do |type, message| %>
      <div class="bg-green-100 border border-green-400 text-green-700 px-4 py-3 text-center">
        <%= message %>
      </div>
    <% end %>

    <!-- メインコンテンツ -->
    <main class="flex-grow">
      <div class="max-w-6xl mx-auto px-6 py-8">
        <%= yield %>
      </div>
    </main>
  </body>
</html>
```

## File: `app/views/layouts/application.html.erb`

```
<!DOCTYPE html>
<html class="<%= (@blog_setting&.theme_color || 'default') %>-theme">
  <head>
    <title><%= @blog_setting&.display_title(I18n.locale) || "Dual Pascal" %></title>
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

  <body class="text-lg bg-white min-h-screen flex flex-col" data-controller="auth-modal" data-action="keydown->auth-modal#closeOnEscape">
    <!-- ページヘッダー -->
    <header class="site-header mb-4">
      <div class="header-container w-full">
        <div class="header-content">
          <%#<nav class="main-nav w-full bg-gray-200">%>
          <nav class="main-nav w-full theme-header">
            <nav class="nav-inner flex max-w-6xl mx-auto items-center justify-end gap-4 h-12 px-6">

            <%= link_to locale_switch_label, locale_switch_url(locale_switch_target), class: "text-gray-500 px-2 py-1 border border-gray-300 bg-white hover:bg-gray-100 font-medium rounded" %>

             <!-- 検索フォームを追加 -->
    <% if params[:username].present? %>
      <div class="header-search">
        <%= form_with url: user_search_path(params[:username], locale: params[:locale] || 'ja'), method: :get, local: true, class: "search-form flex items-center gap-2" do |f| %>
          <%= f.text_field :q,
              placeholder: t('blog.search.placeholder'),
              class: "search-input w-64 border text-gray-500 border-gray-300 rounded-md focus:outline-none focus:ring-1 focus:ring-gray-400 bg-white px-4 py-1",
              value: params[:q] %>
          <%= f.submit t('blog.search.button'),
              class: "btn-unified text-sm" %>
        <% end %>
      </div>
    <% end %>

            <div class="flex items-center gap-4">
              <% if user_signed_in? %>
                <%= link_to "Dashboard", dashboard_articles_path, class: "text-gray-200 hover:text-gray-100 font-medium" %>
                <div class="flex items-center gap-2">
                  <% if current_user.avatar.attached? %>
                    <%= image_tag current_user.avatar, class: "w-8 h-8 rounded-full" %>
                  <% else %>
                    <div class="w-8 h-8 bg-gray-300 rounded-full flex items-center justify-center text-sm">
                      <%= current_user.display_name.first %>
                    </div>
                  <% end %>
                  <%= link_to current_user.display_name, user_profile_path(current_user.username), locale: params[:locale], class: "text-gray-200 hover:text-gray-100 font-medium" %>
                </div>
              <% else %>
                <button data-action="click->auth-modal#showModal" class="btn-unified text-sm">
                  Sign in
                </button>
              <% end %>
            </div>
            </nav>
           </nav>
          <div class="text-center py-10">
            <%= link_to (@blog_setting&.display_title(I18n.locale) || "Dual Pascal"), user_articles_path(@blog_setting.user.username, locale: I18n.locale), class: "text-4xl font-bold py-4 inline-block blog-title" %>
            <% if @blog_setting&.display_subtitle(I18n.locale).present? %>
              <p class="text-lg text-gray-600 mt-2"><%= @blog_setting.display_subtitle(I18n.locale) %></p>
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

    <%= render 'shared/auth_modal' %>
  
    <!-- メインコンテンツ -->
    <main class="main-content flex-grow">
      <div class="content-container max-w-6xl mx-auto px-6 mb-8">
        <%= yield %>
      </div>
    </main>


<!-- フッター部分の更新 -->
<footer class="site-footer">
  <div class="footer-container w-full theme-footer">
    <div class="footer-content max-w-6xl mx-auto px-6 py-4">
      <div class="flex justify-between items-center">
        <p>© 2025 Dual Pascal. All rights reserved.</p>
        <div class="flex gap-4">
          <%= link_to "利用規約", terms_of_service_path, class: "text-sm hover:text-white" %>
          <%= link_to "プライバシーポリシー", privacy_policy_path, class: "text-sm hover:text-white" %>
          <%= link_to "免責事項", disclaimer_path, class: "text-sm hover:text-white" %>
          <%= link_to "運営への問い合わせ", new_contact_path, class: "text-sm hover:text-white" %>
        </div>
      </div>
    </div>
  </div>
</footer>
  </body>
</html>
```

## File: `app/views/layouts/dashboard.html.erb`

```
<!-- app/views/layouts/dashboard.html.erb -->
<!DOCTYPE html>
<html class="<%= ( @blog_setting&.theme_color || 'slate' ) %>-theme">
  <head>
    <title><%= @blog_setting&.display_title(I18n.locale) || "Dual Pascal" %></title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>

    <%= stylesheet_link_tag "medium-style", "data-turbo-track": "reload" %>
    <%= stylesheet_link_tag "syntax-highlighting", "data-turbo-track": "reload" %>
    <%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>
    <%= stylesheet_link_tag "tailwind", "data-turbo-track": "reload" %>

    <%= javascript_importmap_tags %>
  </head>
  <body class="text-lg bg-white min-h-screen flex flex-col">
    <header class="mb-4 w-full theme-header">
      <div class="dashboard-nav flex max-w-6xl mx-auto items-center justify-between h-12">
        <div class="nav-left flex mx-2">
        <h1>
          <%= link_to "管理画面", dashboard_articles_path, class: "mx-2 hover:text-white" %>
        </h1>
          <div class="nav-links">
            <%= link_to "カテゴリ", dashboard_categories_path, class: "mx-2 hover:text-white" %>
            <%= link_to "コメント", dashboard_comments_path, class: "mx-2 hover:text-white" %>
            <%= link_to "プロフィール", edit_dashboard_profile_path, class: "mx-2 hover:text-white" %>
            <%= link_to "ブログ設定", edit_dashboard_blog_setting_path, class: "mx-2 hover:text-white" %>
            <%= link_to "サイトを見る", user_articles_path(current_user.username, locale: I18n.locale), target: "_blank", class: "mx-2 hover:text-white" %>
          </div>
        </div>
        
        <div class="user-info">
          <% if user_signed_in? %>
            <span class="text-gray-300">
              ログイン中: <%= current_user.username %>
            </span>
            <%= link_to "ログアウト", destroy_user_session_path, 
              data: { "turbo-method": "delete" },
              class: "mx-2 hover:text-white"
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

    <div class="container max-w-6xl mx-auto px-6 mb-8 flex-grow">
        <%= yield %>
    </div>

<!-- ダッシュボードフッター部分の更新 -->
<footer class="site-footer">
  <div class="footer-container w-full theme-footer">
    <div class="footer-content max-w-6xl mx-auto px-6 py-4">
      <div class="flex justify-between items-center">
        <p>© 2025 Dual Pascal. All rights reserved.</p>
        <div class="flex gap-4 text-sm">
          <%= link_to "利用規約", terms_of_service_path, class: "hover:text-white" %>
          <%= link_to "プライバシーポリシー", privacy_policy_path, class: "hover:text-white" %>
          <%= link_to "免責事項", disclaimer_path, class: "hover:text-white" %>
        </div>
      </div>
    </div>
  </div>
</footer>
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

## File: `app/views/layouts/mailer.html.slim`

```
html
  body
    = yield
```

## File: `app/views/layouts/mailer.text.erb`

```
<%= yield %>
```

## File: `app/views/layouts/mailer.text.slim`

```
= yield
```

## File: `app/views/legal/disclaimer.en.html.slim`

```
.max-w-4xl.mx-auto.py-8
  .text-center.py-16
    h1.text-3xl.font-bold.mb-8.text-gray-900
      | Disclaimer
    
    .bg-blue-50.border.border-blue-200.rounded-lg.p-8.mb-8
      .mb-6
        svg.mx-auto.h-12.w-12.text-blue-400 fill="none" viewBox="0 0 24 24" stroke="currentColor"
          path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.996-.833-2.464 0L3.34 16.5c-.77.833.192 2.5 1.732 2.5z"
      
      h2.text-xl.font-semibold.mb-4.text-gray-900
        | Content Not Available in English
      
      p.text-gray-700.mb-4
        | Our Disclaimer is currently available in Japanese only.
      
      p.text-gray-700.mb-6
        | This document outlines the limitations of liability for our blogging service 
        | and is governed by Japanese law.
      
      = link_to "View Japanese Version / 日本語版を見る", disclaimer_path(locale: 'ja'), class: "bg-blue-500 hover:bg-blue-600 text-white px-6 py-3 rounded-lg font-semibold inline-block"
```

## File: `app/views/legal/disclaimer.html.slim`

```
.max-w-4xl.mx-auto.py-8
  h1.text-3xl.font-bold.mb-8.text-center Dual Pascal 免責事項

  .bg-white.rounded-lg.border.border-gray-200.shadow-sm.p-8
    .space-y-8
      section
        h2.text-xl.font-semibold.mb-4.text-gray-900 1. 免責事項の概要
        p.text-gray-700.leading-relaxed
          | Dual Pascal（以下「当サービス」）は、ユーザーが安心してご利用いただけるよう努めておりますが、技術的制約等により完全性を保証することはできません。本免責事項は、当サービスの利用に関して運営者が負う責任の範囲を明確にするものです。

      section
        h2.text-xl.font-semibold.mb-4.text-gray-900 2. サービス内容に関する免責
        .space-y-4
          p.text-gray-700.leading-relaxed
            | 1. 運営者は、当サービスの内容について、その正確性、安全性、有用性、完全性、継続性等について、明示的にも暗黙的にも一切保証いたしません。
          p.text-gray-700.leading-relaxed
            | 2. 当サービスは現状有姿で提供されており、運営者は技術的瑕疵やセキュリティホール等の存在可能性を否定いたしません。
          p.text-gray-700.leading-relaxed
            | 3. 運営者は、ユーザーが当サービスを利用することによって得られる情報等について、その正確性、有用性、完全性等について一切保証いたしません。

      section
        h2.text-xl.font-semibold.mb-4.text-gray-900 3. ユーザー投稿コンテンツに関する免責
        .space-y-4
          p.text-gray-700.leading-relaxed
            | 1. 当サービスにユーザーが投稿したブログ記事、コメント、画像等のコンテンツ（以下「ユーザーコンテンツ」）の内容について、運営者は一切の責任を負いません。
          p.text-gray-700.leading-relaxed
            | 2. ユーザーコンテンツが第三者の著作権、肖像権、その他の権利を侵害した場合、当該ユーザーが自己の責任と費用負担において解決するものとし、運営者は一切の責任を負いません。
          p.text-gray-700.leading-relaxed
            | 3. ユーザーコンテンツの正確性、適法性、道徳性等については、投稿したユーザーが全ての責任を負うものとし、運営者は一切関与いたしません。

      section
        h2.text-xl.font-semibold.mb-4.text-gray-900 4. システム障害・データ消失に関する免責
        .space-y-4
          p.text-gray-700.leading-relaxed
            | 1. 運営者は、以下の事由によるサービスの中断、停止、データの消失等について一切の責任を負いません。
          ul.list-disc.ml-6.text-gray-700.space-y-1
            li システムメンテナンス
            li サーバー機器の故障、不具合
            li 自然災害、停電
            li 通信回線の障害
            li サイバー攻撃、不正アクセス
            li その他運営者の責に帰さない事由
          p.text-gray-700.leading-relaxed
            | 2. ユーザーは自己の責任において、重要なデータについては定期的にバックアップを取ることを推奨いたします。

      section
        h2.text-xl.font-semibold.mb-4.text-gray-900 5. 第三者サービスとの連携に関する免責
        .space-y-4
          p.text-gray-700.leading-relaxed
            | 1. 当サービスでは、GitHub、Google等の第三者が提供するOAuthサービスを利用した認証機能を提供しております。これらの第三者サービスに関する問題については、運営者は一切の責任を負いません。
          p.text-gray-700.leading-relaxed
            | 2. 当サービスに外部サイトへのリンクが含まれる場合がありますが、リンク先サイトの内容、安全性等について運営者は一切の責任を負いません。

      section
        h2.text-xl.font-semibold.mb-4.text-gray-900 6. 損害賠償の限定
        .space-y-4
          p.text-gray-700.leading-relaxed
            | 1. 運営者の債務不履行または不法行為によりユーザーに損害が生じた場合、運営者の損害賠償責任は、現実に発生した直接損害に限定され、特別損害、間接損害、逸失利益、精神的損害等については、一切責任を負いません。
          p.text-gray-700.leading-relaxed
            | 2. 前項の規定にかかわらず、運営者の故意または重過失による場合は、この限りではありません。
          p.text-gray-700.leading-relaxed
            | 3. 消費者契約法の適用がある場合、同法の規定に従います。

      section
        h2.text-xl.font-semibold.mb-4.text-gray-900 7. ユーザー間トラブルに関する免責
        .space-y-4
          p.text-gray-700.leading-relaxed
            | 1. ユーザー間で生じたトラブル、争議等については、当事者間で解決していただくものとし、運営者は一切関与いたしません。
          p.text-gray-700.leading-relaxed
            | 2. ただし、運営者が必要と認めた場合には、コンテンツの削除、ユーザーアカウントの停止等の措置を取ることがあります。

      section
        h2.text-xl.font-semibold.mb-4.text-gray-900 8. 法令の遵守
        p.text-gray-700.leading-relaxed
          | ユーザーは、当サービスの利用にあたり、関連する法令を遵守し、第三者の権利を侵害しないよう注意する責任を負います。法令違反や権利侵害に起因する問題については、当該ユーザーが全ての責任を負うものとします。

      section
        h2.text-xl.font-semibold.mb-4.text-gray-900 9. 免責事項の変更
        .space-y-4
          p.text-gray-700.leading-relaxed
            | 1. 運営者は、必要に応じて本免責事項を変更することがあります。
          p.text-gray-700.leading-relaxed
            | 2. 変更後の免責事項は、当サイトに掲載された時点で効力を生じるものとします。
          p.text-gray-700.leading-relaxed
            | 3. 重要な変更については、適切な方法でユーザーに通知いたします。

      section
        h2.text-xl.font-semibold.mb-4.text-gray-900 10. お問い合わせ
        p.text-gray-700.leading-relaxed
          | 本免責事項に関するご質問は、
          = link_to "お問い合わせフォーム", new_contact_path, class: "text-blue-600 hover:text-blue-800 underline"
          | よりご連絡ください。

      .mt-12.pt-8.border-t.border-gray-200.text-right.text-gray-600
        p 制定日：2025年1月1日
        p.mt-2
          | 本免責事項に関するお問い合わせは
          = link_to "こちら", new_contact_path, class: "text-blue-600 hover:text-blue-800 underline"
          | からお願いいたします。
```

## File: `app/views/legal/privacy_policy.en.html.slim`

```
.max-w-4xl.mx-auto.py-8
  .text-center.py-16
    h1.text-3xl.font-bold.mb-8.text-gray-900
      | Privacy Policy
    
    .bg-blue-50.border.border-blue-200.rounded-lg.p-8.mb-8
      .mb-6
        svg.mx-auto.h-12.w-12.text-blue-400 fill="none" viewBox="0 0 24 24" stroke="currentColor"
          path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"
      
      h2.text-xl.font-semibold.mb-4.text-gray-900
        | Content Not Available in English
      
      p.text-gray-700.mb-4
        | Our Privacy Policy is currently available in Japanese only.
      
      p.text-gray-700.mb-6
        | This policy explains how we collect, use, and protect your personal information 
        | in accordance with Japanese privacy laws and regulations.
      
      = link_to "View Japanese Version / 日本語版を見る", privacy_policy_path(locale: 'ja'), class: "bg-blue-500 hover:bg-blue-600 text-white px-6 py-3 rounded-lg font-semibold inline-block"
```

## File: `app/views/legal/privacy_policy.html.slim`

```
.max-w-4xl.mx-auto.py-8
  h1.text-3xl.font-bold.mb-8.text-center Dual Pascal プライバシーポリシー

  .bg-white.rounded-lg.border.border-gray-200.shadow-sm.p-8
    .space-y-8
      section
        h2.text-xl.font-semibold.mb-4.text-gray-900 1. 個人情報の定義
        p.text-gray-700.leading-relaxed
          | 本プライバシーポリシーにおいて、「個人情報」とは、個人情報保護法にいう「個人情報」を指すものとし、生存する個人に関する情報であって、当該情報に含まれる氏名、生年月日、住所、電話番号、連絡先その他の記述等により特定の個人を識別できる情報及び容貌、指紋、声紋にかかるデータ、及び健康保険証の保険者番号などの当該情報単体から特定の個人を識別できる情報（個人識別情報）を指します。

      section
        h2.text-xl.font-semibold.mb-4.text-gray-900 2. 個人情報の収集方法
        .space-y-4
          p.text-gray-700.leading-relaxed
            | 運営者は、ユーザーが利用登録をする際に、メールアドレス、ユーザーネーム等の個人情報をお尋ねすることがあります。また、ユーザーと提携先などとの間でなされたユーザーの個人情報を含む取引記録や決済に関する情報を、運営者の提携先（情報提供元、広告主、広告配信先などを含みます。以下、「提携先」といいます。）などから収集することがあります。
          p.text-gray-700.leading-relaxed
            | 運営者は、ユーザーについて、利用したサービスやソフトウェア、購入した商品、閲覧したページや広告の履歴、検索した検索キーワード、利用日時、利用の方法、利用環境、郵便番号や性別、職業、年齢、ユーザーのIPアドレス、クッキー情報、位置情報、端末の個体識別情報などの履歴情報および特性情報を、ユーザー運営者や提携先のサービスを利用し、またはページを閲覧する際に収集します。

      section
        h2.text-xl.font-semibold.mb-4.text-gray-900 3. 個人情報を収集・利用する目的
        .space-y-4
          p.text-gray-700.leading-relaxed 運営者が個人情報を収集・利用する目的は、以下のとおりです。
          ul.list-disc.ml-6.text-gray-700.space-y-2
            li 運営者サービスの提供・運営のため
            li ユーザーからのお問い合わせに回答するため
            li 運営者が行うアンケートやキャンペーンに関するご連絡のため
            li ユーザーの本人確認のため
            li ユーザーが利用中のサービスの新機能、更新情報、キャンペーン等及び運営者が提供する他のサービスの案内のため
            li メンテナンス、重要なお知らせなど必要に応じたご連絡のため
            li 利用規約に違反したユーーや、不正・不当な目的でサービスを利用しようとするユーザーの特定をし、ご利用をお断りするため
            li ユーザーにご自身の登録情報の閲覧や変更、削除、ご利用状況の閲覧を行っていただくため
            li 有料サービスにおいて、ユーザーに利用料金を請求するため
            li 上記の利用目的に付随する目的

      section
        h2.text-xl.font-semibold.mb-4.text-gray-900 4. 利用目的の変更
        p.text-gray-700.leading-relaxed
          | 運営者は、利用目的が変更前と関連性を有すると合理的に認められる場合に限り、個人情報の利用目的を変更するものとします。利用目的の変更を行った場合には、変更後の目的について、運営者所定の方法により、ユーザーに通知し、または本ウェブサイト上に公表するものとします。

      section
        h2.text-xl.font-semibold.mb-4.text-gray-900 5. 個人情報の第三者提供
        .space-y-4
          p.text-gray-700.leading-relaxed
            | 運営者は、次に掲げる場合を除いて、あらかじめユーザーの同意を得ることなく、第三者に個人情報を提供することはありません。ただし、個人情報保護法その他の法令で認められる場合を除きます。
          ul.list-disc.ml-6.text-gray-700.space-y-2
            li 人の生命、身体または財産の保護のために必要がある場合であって、本人の同意を得ることが困難であるとき
            li 公衆衛生の向上または児童の健全な育成の推進のために特に必要がある場合であって、本人の同意を得ることが困難であるとき
            li 国の機関もしくは地方公共団体またはその委託を受けた者が法令の定める事務を遂行することに対して協力する必要がある場合であって、本人の同意を得ることにより当該事務の遂行に支障を及ぼすおそれがあるとき
            li 予め次の事項を告知あるいは公表し、かつ運営者が個人情報保護委員会に届出をしたとき
            ul.list-disc.ml-6.text-gray-600.space-y-1.mt-2
              li 利用目的に第三者への提供を含むこと
              li 第三者に提供されるデータの項目
              li 第三者への提供の手段または方法
              li 本人の求めに応じて個人情報の第三者への提供を停止すること
              li 本人の求めを受け付ける方法

      section
        h2.text-xl.font-semibold.mb-4.text-gray-900 6. 個人情報の開示
        .space-y-4
          p.text-gray-700.leading-relaxed
            | 運営者は、本人から個人情報の開示を求められたときは、本人に対し、遅滞なくこれを開示します。ただし、開示することにより次のいずれかに該当する場合は、その全部または部を開示しないこともあり、開示しない決定をした場合には、その旨を遅滞なく通知します。
          ul.list-disc.ml-6.text-gray-700.space-y-1
            li 本人または第三者の生命、身体、財産その他の権利利益を害するおそれがある場合
            li 運営者の業務の適正な実施に著しい支障を及ぼすおそれがある場合
            li その他法令に違反することとなる場合

      section
        h2.text-xl.font-semibold.mb-4.text-gray-900 7. 個人情報の訂正および削除
        .space-y-4
          p.text-gray-700.leading-relaxed
            | 1. ユーザーは、運営者の保有する自己の個人情報が誤った情報である場合には、運営者が定める手続きにより、運営者に対して個人情報の訂正、追加または削除（以下、「訂正等」といいます。）を請求することができます。
          p.text-gray-700.leading-relaxed
            | 2. 運営者は、ユーザーから前項の請求を受けてその請求に理由があると判断した場合には、遅滞なく、当該個人情報の訂正等を行うものとします。
          p.text-gray-700.leading-relaxed
            | 3. 運営者は、前項の規定に基づき訂正等を行った場合、または訂正等を行わない旨の決定をしたときは遅滞なく、これをユーザーに通知します。

      section
        h2.text-xl.font-semibold.mb-4.text-gray-900 8. 個人情報の利用停止等
        .space-y-4
          p.text-gray-700.leading-relaxed
            | 運営者は、本人から、個人情報が、利用目的の範囲を超えて取り扱われているという理由、または不正の手段により取得されたものであるという理由により、その利用の停止または消去（以下、「利用停止等」といいます。）を求められた場合には、遅滞なく必要な調査を行います。
          p.text-gray-700.leading-relaxed
            | 前項の調査結果に基づき、その請求に理由があると判断した場合には、遅滞なく、当該個人情報の利用停止等を行います。ただし、個人情報の利用停止等に多額の費用を有する場合その他利用停止等を行うことが困難な場合であって、ユーザーの権利利益を保護するために必要なこれに代わるべき措置をとれる場合は、この代替策を講じるものとします。

      section
        h2.text-xl.font-semibold.mb-4.text-gray-900 9. プライバシーポリシーの変更
        .space-y-4
          p.text-gray-700.leading-relaxed
            | 1. 本ポリシーの内容は、法令その他本ポリシーに別段の定めのある事項を除いて、ユーザーに通知することなく、変更することができるものとします。
          p.text-gray-700.leading-relaxed
            | 2. 運営者が別途定める場合を除いて、変更後のプライバシポリシーは、本ウェブサイトに掲載したときから効力を生じるものとします。

      section
        h2.text-xl.font-semibold.mb-4.text-gray-900 10. お問い合わせ窓口
        p.text-gray-700.leading-relaxed
          | 本ポリシーに関するお問い合わせは、
          = link_to "お問い合わせフォーム", new_contact_path, class: "text-blue-600 hover:text-blue-800 underline"
          | よりご連絡ください。

      .mt-12.pt-8.border-t.border-gray-200.text-right.text-gray-600
        p 制定日：2025年1月1日
        p.mt-2
          | 本ポリシーに関するお問い合わせは
          = link_to "こちら", new_contact_path, class: "text-blue-600 hover:text-blue-800 underline"
          | からお願いいたします。

```

## File: `app/views/legal/terms_of_service.en.html.slim`

```
.max-w-4xl.mx-auto.py-8
  .text-center.py-16
    h1.text-3xl.font-bold.mb-8.text-gray-900
      | Terms of Service
    
    .bg-blue-50.border.border-blue-200.rounded-lg.p-8.mb-8
      .mb-6
        svg.mx-auto.h-12.w-12.text-blue-400 fill="none" viewBox="0 0 24 24" stroke="currentColor"
          path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
      
      h2.text-xl.font-semibold.mb-4.text-gray-900
        | Content Not Available in English
      
      p.text-gray-700.mb-4
        | We apologize, but our Terms of Service is currently available in Japanese only.
      
      p.text-gray-700.mb-6
        | Dual Pascal is a blogging platform primarily designed for Japanese users. 
        | All legal documents are provided in Japanese to ensure legal accuracy and compliance with Japanese law.
      
      = link_to "View Japanese Version / 日本語版を見る", terms_of_service_path(locale: 'ja'), class: "bg-blue-500 hover:bg-blue-600 text-white px-6 py-3 rounded-lg font-semibold inline-block"
```

## File: `app/views/legal/terms_of_service.html.slim`

```
.max-w-4xl.mx-auto.py-8
  h1.text-3xl.font-bold.mb-8.text-center Dual Pascal 利用規約

  .bg-white.rounded-lg.border.border-gray-200.shadow-sm.p-8
    .space-y-8
      section
        h2.text-xl.font-semibold.mb-4.text-gray-900 第1条（適用）
        p.text-gray-700.leading-relaxed
          | 本利用規約（以下「本規約」といいます。）は、Dual Pascal（以下「本サービス」といいます。）の利用条件を定めるものです。ユーザーの皆様には、本規約に従って本サービスをご利用いただきます。

      section
        h2.text-xl.font-semibold.mb-4.text-gray-900 第2条（利用登録）
        .space-y-4
          p.text-gray-700.leading-relaxed
            | 1. 本サービスの利用を希望する方は、本規約に同意の上、運営者の定める方法によって利用登録を申請し、運営者がこれを承認することによって、利用登録が完了するものとします。
          p.text-gray-700.leading-relaxed
            | 2. 運営者は、利用登録の申請者に以下の事由があると判断した場合、利用登録の申請を承認しないことがあります。
          ul.list-disc.ml-6.text-gray-700.space-y-1
            li 利用登録の申請に際して虚偽の事項を届け出た場合
            li 本規約に違反したことがある者からの申請である場合
            li その他、運営者が利用登録を相当でないと判断した場合

      section
        h2.text-xl.font-semibold.mb-4.text-gray-900 第3条（ユーザーIDおよびパスワードの管理）
        .space-y-4
          p.text-gray-700.leading-relaxed
            | 1. ユーザーは、自己の責任において、本サービスのユーザーIDおよびパスワードを適切に管理するものとします。
          p.text-gray-700.leading-relaxed
            | 2. ユーザーは、いかなる場合にも、ユーザーIDおよびパスワードを第三者に譲渡または貸し、もしくは第三者と共用することはできません。
          p.text-gray-700.leading-relaxed
            | 3. ユーザーIDおよびパスワードが第三者によって使用されたことによって生じた損害は、ユーザーが負担するものとします。

      section
        h2.text-xl.font-semibold.mb-4.text-gray-900 第4条（禁止事項）
        .space-y-4
          p.text-gray-700.leading-relaxed ユーザーは、本サービスの利用にあたり、以下の行為をしてはなりません。
          ul.list-disc.ml-6.text-gray-700.space-y-2
            li 法令または公序良俗に違反する行為
            li 犯罪行為に関連する行為
            li 運営者、本サービスの他のユーザー、または第三者の知的財産権、肖像権、プライバシー、名誉その他の権利または利益を侵害する行為
            li 本サービスを通じ、以下のような有害な情報を送信する行為
            ul.list-disc.ml-6.text-gray-600.space-y-1.mt-2
              li 過度に暴力的な表現
              li 露骨な性的表現
              li 人種、国籍、信条、性別、社会的身分、門地等による差別につながる表現
              li 自殺、自傷行為、薬物乱用を誘引または助長する表現
              li その他反社会的な内容を含み他人に不快感を与える表現
            li 本サービスのネットワークまたはシステム等に過度な負荷をかける行為
            li 本サービスの運営を妨害するおそれのある行為
            li 運営者のサーバーやネットワーク等に不正にアクセスする行為
            li 第三者のIDまたはパスワードを不正に使用する行為
            li 営業、宣伝、広告、勧誘、その他営利を目的とする行為
            li 面識のない異性との出会いや交際を目的とする行為
            li 他のユーザーに関する個人情報の収集または蓄積行為
            li 違法、不正または不当な目的を持って本サービスを利用する行為
            li 反社会的勢力に対して直接または間接に利益を供与する行為
            li その他、運営者が不適切と判断する行為

      section
        h2.text-xl.font-semibold.mb-4.text-gray-900 第5条（本サービスの提供の停止等）
        .space-y-4
          p.text-gray-700.leading-relaxed
            | 運営者は、以下のいずれかの事由があると判断した場合、ユーザーに事前に通知することなく本サービスの全部または一部の提供を停止または中断することができるものとします。
          ul.list-disc.ml-6.text-gray-700.space-y-1
            li 本サービスにかかるコンピュータシステムの保守点検または更新を行う場合
            li 地震、落雷、火災、停電または天災などの不可抗力により、本サースの提供が困難となった場合
            li コンピュータまたは通信回線等が事故により停止した場合
            li その他、運営者が本サービスの提供が困難と判断した場合

      section
        h2.text-xl.font-semibold.mb-4.text-gray-900 第6条（著作権）
        .space-y-4
          p.text-gray-700.leading-relaxed
            | 1. ユーザーが本サービスを利用して投稿したテキスト、画像、動画等のコンテンツの著作権は、当該ユーザーその他既存の権利者に留保されます。
          p.text-gray-700.leading-relaxed
            | 2. ユーザーは、投稿したコンテンツについて、運営者が本サービスの運営、改善、プロモーション等に必要な範囲で利用（複製、送信、表示、配布等を含みます。）することについて、無償で許諾するものとします。
          p.text-gray-700.leading-relaxed
            | 3. 前項の利用許諾は、ユーザーが本サービスを退会した場合であっても、合理的な期間、存続するものとします。

      section
        h2.text-xl.font-semibold.mb-4.text-gray-900 第7条（利用制限および登録抹消）
        .space-y-4
          p.text-gray-700.leading-relaxed
            | 1. 運営者は、ユーザーが以下のいずれかに該当する場合には、事前の通知なく、当該ユーザーに対して、本サービスの全部もしくは一部の利用を制限し、またはユーザーとしての登録を抹消することができるものとします。
          ul.list-disc.ml-6.text-gray-700.space-y-1
            li 本規約のいずれかの条項に違反した場合
            li 登録事項に虚偽の事実があることが判明した場合
            li 料金等の支払債務の不履行があった場合
            li 運営者からの連絡に対し、一定期間返答がない場合
            li 本サービスについて、最後の用から一定期間利用がない場合
            li その他、運営者が本サービスの利用を適当でないと判断した場合
          p.text-gray-700.leading-relaxed
            | 2. 前項各号のいずれかに該当した場合、ユーザーは、当然に運営者に対する一切の債務について期限の利益を失い、その時点において負担する一切の債務を直ちに一括して弁済しなければなりません。

      section
        h2.text-xl.font-semibold.mb-4.text-gray-900 第8条（料金および支払方法）
        .space-y-4
          p.text-gray-700.leading-relaxed
            | 1. 本サービスは現在無料で提供されております。
          p.text-gray-700.leading-relaxed
            | 2. 運営者は、本サービスの一部または全部を有料化する権利を留保します。有料化を行う場合は、事前にユーザーに対し適切な方法で通知いたします。
          p.text-gray-700.leading-relaxed
            | 3. 有料化後の料金およびお支払い方法については、別途定めるものとします。

      section
        h2.text-xl.font-semibold.mb-4.text-gray-900 第9条（保証の否認および免責事項）
        .space-y-4
          p.text-gray-700.leading-relaxed
            | 1. 運営者は、本サービスに事実上または法律上の瑕疵（安全性、信頼性、正確性、完全性、有効性、特定の目的への適合性、セキュリティなどに関する欠陥、エラーやバグ、権利侵害などを含みます。）がないことを明示的にも黙示的にも保証しておりません。
          p.text-gray-700.leading-relaxed
            | 2. 運営者は、本サービスに起因してユーザーに生じたあらゆる損害について、一切の責任を負いません。ただし、本サービスに関する運営者とユーザーとの間の契約が消費者契約法に定める消費者契約となる場合、この免責規定は適されません。

      section
        h2.text-xl.font-semibold.mb-4.text-gray-900 第10条（サービス内容の変更等）
        p.text-gray-700.leading-relaxed
          | 運営者は、ユーザーへの事前の告知をもって、本サービスの内容を変更、追加または廃止することがあり、ユーザーはこれを承諾するものとします。

      section
        h2.text-xl.font-semibold.mb-4.text-gray-900 第11条（利用規約の変更）
        .space-y-4
          p.text-gray-700.leading-relaxed
            | 1. 運営者は以下の場合には、ユーザーの個別の同意を要せず、本規約を変更することができるものとします。
          ul.list-disc.ml-6.text-gray-700.space-y-1
            li 本規約の変更がユーザーの一般の利益に適合するとき
            li 本規約の変更が本サービス利用契約の目的に反せず、かつ、変更の必要性、変更後の内容の相当性その他の変更に係る情に照らして合理的なものであるとき
          p.text-gray-700.leading-relaxed
            | 2. 運営者は前項による規約の変更をする場合には、事前に、本規約を変更する旨および変更後の規約の内容ならびにその効力発生時期をウェブサイト上での掲示その他の適切な方法により周知するものとします。

      section
        h2.text-xl.font-semibold.mb-4.text-gray-900 第12条（個人情報の取扱い）
        p.text-gray-700.leading-relaxed
          | 運営者は、本サービスの利用によって取得する個人情報については、運営者の「プライバシーポリシー」に従い適切に取り扱うものとします。

      section
        h2.text-xl.font-semibold.mb-4.text-gray-900 第13条（通知または連絡）
        p.text-gray-700.leading-relaxed
          | ユーザーと運営者との間の通知または連絡は、運営者の定める方法によって行うものとします。運営者、ユーザーから、運営者が別途定める方式に従った変更届け出がない限り、現在登録されている連絡先が有効なものとみなして当該連絡先へ通知または連絡を行い、これらは、発信時にユーザーへ到達したものとみなします。

      section
        h2.text-xl.font-semibold.mb-4.text-gray-900 第14条（権利義務の譲渡の禁止）
        p.text-gray-700.leading-relaxed
          | ユーザーは、運営者の書面による事前の承諾なく、利用契約上の地位または本規約に基づく権利もしくは義務を第三者に譲渡し、または担保に供することはできません。

      section
        h2.text-xl.font-semibold.mb-4.text-gray-900 第15条（準拠法・裁判管轄）
        .space-y-4
          p.text-gray-700.leading-relaxed
            | 1. 本規約の解釈にあたっては、日本法を準拠法とします。
          p.text-gray-700.leading-relaxed
            | 2. 本サースに関して紛争が生じた場合には、運営者の所在地を管轄する裁判所を専属的合意管轄とします。

      .mt-12.pt-8.border-t.border-gray-200.text-right.text-gray-600
        p 制定日：2025年1月1日
        p.mt-2
          | 本規約に関するお問い合わせは
          = link_to "こちら", new_contact_path, class: "text-blue-600 hover:text-blue-800 underline"
          | からお願いいたします。

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

        .flex.flex_wrap.gap-3.mt-4
          - if @user.website.present?
            = link_to @user.website, target: "_blank" do
              | 🌐 Website
          - if @user.twitter_handle.present?
            = link_to "https://x.com/#{@user.twitter_handle.delete('@')}", target: "_blank" do
              | X
          - if @user.facebook_handle.present?
            = link_to "https://facebook.com/#{@user.facebook_handle}", target: "_blank" do
              | Facebook
            - if @user.github_handle.present?
              = link_to "https://github.com/#{@user.github_handle}", target: "_blank" do
                | GitHub
            - if @user.qiita_handle.present?
              = link_to "https://qiita.com/#{@user.qiita_handle}", target: "_blank" do
                | Qiita
            - if @user.zenn_handle.present?
              = link_to "https://zenn.dev/#{@user.zenn_handle}", target: "_blank" do
                | Zenn
            - if @user.hatena_handle.present?
              = link_to "https://#{@user.hatena_handle}.hatenablog.com/", target: "_blank" do
                | はてなブログ
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
h1= t('blog.search.results')

/ 検索結果の表示
- if @search_keyword.present?
  p style="margin-bottom: 20px;"
    | 「#{@search_keyword}」#{t('blog.search.results_count', count: @articles.total_count)}
    = link_to t('blog.search.back_to_articles'), user_articles_path(username: params[:username], locale: params[:locale]), style: "margin-left: 20px;"
- else
  p= t('blog.search.no_keyword')
  = link_to t('blog.search.back_to_articles'), user_articles_path(locale: params[:locale]), style: "margin-left: 20px;"



- @articles.each do |article|
  .article-item.mb-8.p-6.border-b.border-gray-500
    .article-header.max-w-3xl.mx-auto
      h2.text-4xl.font-extrabold.mb-4.mt-8.text-gray-900.border-b.border-gray-500.pb-2
        = link_to article.title, user_article_path(article.user.username, article.id, locale: params[:locale])

      .article-meta.pb-3.mb-4
        - if article.category.present?
          p.pb-2
            | #{t('blog.category')}:
            = link_to article.category.name, user_articles_path(params[:username], @filter.filter_params.merge(category_id: article.category.id))

        = render 'shared/article_tags', article: article, filter_params: @filter.filter_params

      .meta-content-divider.text-center.mx-8
        span.text-gray-400.text-xl • • •

    .article-content.medium-container style="all: revert;"
      div class="medium"
        = article.content_html

    .article-meta.max-w-3xl.mx-auto.text-right
      p
        | #{t('blog.published_at')}: 
        = article.published_at&.strftime('%Y年%m月%d日')
      p
        | #{t('blog.updated_at')}: 
        = article.updated_at&.strftime('%Y年%m月%d日')

      - if article.translation.present?
        p= link_to "#{article.locale == 'ja' ? 'English' : '日本語'}版", user_article_path(article.translation.user.username, article.translation.id, locale: article.translation.locale)

= paginate @articles






/ 記事一覧表示（articles/index.html.slim と同じ構造）

/- @articles.each do |article|
/  .article-item style="margin-bottom: 30px; padding: 20px; border: 1px solid #ddd;"
/    h2= link_to article.title, user_article_path(article.user.username, article.id, locale: params[:locale])
/
/    - if article.category.present?
/      p
/        | カテゴリ: 
/        strong= article.category.name
/
/    - if article.tags.any?
/      p
/        | タグ: 
/        - article.tags.each_with_index do |tag, index|
/          strong= tag.name
/          - if index < article.tags.size - 1
/            | , 
/
/    .article-content= article.content_html
/    p
/      strong 投稿日: 
/      = article.published_at&.strftime('%Y年%m月%d日')
/
/= paginate @articles
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
        = link_to user_articles_path(params[:username], filter_params.merge(tag_id: t.id)), class: "bg-blue-100 text-blue-800 text-xs font-semibold px-2.5 py-0.5 rounded hover:bg-blue-200" do
          = t.name
```

## File: `app/views/shared/_article_thumbnail.html.slim`

```
.article-thumbnail.p-4
  - if has_cover_image?(article)
    = image_tag thumbnail_for_article(article, blog_setting), 
        class: "w-full h-48 object-cover rounded-lg border border-gray-200"
  - else
    .default-thumbnail
      = blog_setting&.display_title(I18n.locale) || "Dual Pascal"
  
  .mt-3
    h3.text-lg.font-semibold.line-clamp-2
      = link_to article.title, user_article_path(article.user.username, article.id, locale: article.locale),
          class: "text-gray-900 hover:text-blue-600"

  .flex.flex-wrap.items-center.gap-3.mt-2.text-xs.text-gray-600
    - if article.category.present?
      span
        | #{t('blog.category')}: 
        = link_to article.category.name, user_articles_path(params[:username], filter_params.merge(category_id: article.category.id)), class: ""
      
    - if article.tags.any?
      .flex.items-center.gap-1
        span
          | #{t('blog.tags')}: 
        - article.tags.limit(3).each do |tag|
          span.inline-block.bg-blue-100.text-blue-800.px-2.py-1.rounded.text-xs
            = link_to tag.name, user_articles_path(params[:username], filter_params.merge(tag_id: tag.id)), class: ""

      span
        | #{t('blog.published_at')}: 
        = article.published_at&.strftime('%Y年%m月%d日') || article.created_at.strftime('%Y年%m月%d日')
```

## File: `app/views/shared/_auth_modal.html.slim`

```
.fixed.inset-0.bg-black.bg-opacity-50.flex.items-center.justify-center.z-50.hidden data-auth-modal-target="modal" data-action="click->auth-modal#closeOnOutsideClick"
  .bg-white.rounded-lg.p-6.w-96.max-w-90vw data-action="click->auth-modal#stopPropagation"
    .flex.justify-between.items-center.mb-6
      h3.text-xl.font-semibold data-auth-modal-target="title" Sign in to your account
      button.text-gray-400.hover:text-gray-600 data-action="click->auth-modal#closeModal" ×
    
    / OAuth ボタン
    .space-y-3.mb-6
      = button_to omniauth_authorize_path(:user, :github), data: { turbo: false }, class: "w-full btn-unified flex items-center justify-center gap-2" do
        | Continue with GitHub
      = button_to omniauth_authorize_path(:user, :google_oauth2), data: { turbo: false }, class: "w-full btn-unified flex items-center justify-center gap-2" do
        | Continue with Google
    
    .relative.mb-6
      .absolute.inset-0.flex.items-center
        .w-full.border-t.border-gray-300
      .relative.flex.justify-center.text-sm
        span.bg-white.px-2.text-gray-500 or
    
    / Sign in フォーム
    .signin-form data-auth-modal-target="signinForm"
      = form_with model: User.new, url: user_session_path, local: true, class: "space-y-4" do |f|
        .space-y-4
          = f.email_field :email, placeholder: "Email", class: "w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-1 focus:ring-gray-500", required: true
          = f.password_field :password, placeholder: "Password", class: "w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-1 focus:ring-gray-500", required: true
        = f.submit "Sign in", class: "w-full btn-unified"
      .text-center.mt-4
        span.text-gray-600 Don't have an account? 
        button.text-blue-600.hover:text-blue-800 data-action="click->auth-modal#switchToSignup" Sign up
    
    / Sign up フォーム（初期状態は非表示）
    .signup-form.hidden data-auth-modal-target="signupForm"
      = form_with model: User.new, url: user_registration_path, local: true, class: "space-y-4" do |f|
        .space-y-4
          = f.email_field :email, placeholder: "Email", class: "w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-1 focus:ring-gray-500", required: true
          = f.text_field :username, placeholder: "Username", class: "w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-1 focus:ring-gray-500", required: true
          = f.password_field :password, placeholder: "Password (6 characters minimum)", class: "w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-1 focus:ring-gray-500", required: true
          = f.password_field :password_confirmation, placeholder: "Confirm Password", class: "w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-1 focus:ring-gray-500", required: true
        = f.submit "Create account", class: "w-full btn-unified"
      .text-center.mt-4
        span.text-gray-600 Already have an account? 
        button.text-blue-600.hover:text-blue-800 data-action="click->auth-modal#switchToSignin" Sign in
```

## File: `app/views/welcome/index.html.slim`

```
<!-- app/views/welcome/index.html.slim -->
.min-h-screen.flex.flex-col.justify-center.items-center.bg-gray-50
  .max-w-4xl.mx-auto.text-center.px-6
    h1.text-5xl.font-bold.mb-6.text-gray-900
      | Dual Pascal
    p.text-xl.text-gray-600.mb-8
      | 日英バイリンガルブログプラットフォーム
    
    .flex.gap-4.justify-center
      button.bg-blue-500.hover:bg-blue-600.text-white.px-8.py-3.rounded-lg.font-semibold data-action="click->auth-modal#showModal"
        | はじめる
      
      = link_to 'デモを見る', '#', class: "border-2 border-gray-300 hover:border-gray-400 text-gray-700 px-8 py-3 rounded-lg font-semibold"
```

## File: `config/routes.rb`

```
Rails.application.routes.draw do
  get "contacts/new"
  get "contacts/create"
  devise_for :users, controllers: { omniauth_callbacks: "users/omniauth_callbacks" }
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
  root "welcome#index"

  scope "u" do
    get "/:username/search", to: "search#index", as: :user_search
    get "/:username/articles", to: "articles#index", as: :user_articles
    get "/:username/articles/:id", to: "articles#show", as: :user_article
    post "/:username/articles/:article_id/comments", to: "comments#create", as: :user_article_comments
    get ":username/profile", to: "profiles#show", as: :user_profile
  end

  get "/terms-of-service", to: "legal#terms_of_service", as: :terms_of_service
  get "/privacy-policy", to: "legal#privacy_policy", as: :privacy_policy
  get "/disclaimer", to: "legal#disclaimer", as: :disclaimer


  resources :contacts, only: [ :new, :create ]
end

namespace :dashboard do
  resources :articles do
    resource :export, only: [ :show ]
    resource :translation, only: %i[show create update destroy new edit]
  end
  resources :comments, only: %i[index show destroy]
  resources :categories
  post "categories", to: "categories#create", defaults: { format: :json }
  resource :preview, only: [ :create ]
  resources :images, only: [ :create ]
  resource :profile, only: %i[edit update]
  resource :blog_setting, only: %i[edit update]
end

get "/dashboard", to: redirect("/dashboard/articles")
get "/", to: redirect("/ja")

namespace :admin do
  resources :users, only: [ :index, :show, :update ]
  resources :articles, only: [ :index, :destroy ]
  resources :contacts, only: [ :index, :show, :update ]

  root "dashboard#index"
end
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

ActiveRecord::Schema[8.0].define(version: 2025_12_27_004959) do
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
    t.string "blog_title_ja"
    t.string "blog_subtitle_ja"
    t.string "theme_color", default: "slate"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "blog_title_en"
    t.string "blog_subtitle_en"
    t.string "layout_style", default: "linear"
    t.boolean "show_hero_thumbnail", default: false
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

  create_table "contacts", force: :cascade do |t|
    t.string "name"
    t.string "email"
    t.string "subject"
    t.text "message"
    t.boolean "resolved", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_contacts_on_created_at"
    t.index ["resolved"], name: "index_contacts_on_resolved"
  end

  create_table "tags", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["name", "user_id"], name: "index_tags_on_name_and_user_id", unique: true
    t.index ["user_id"], name: "index_tags_on_user_id"
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
    t.string "github_handle"
    t.string "qiita_handle"
    t.string "zenn_handle"
    t.string "hatena_handle"
    t.integer "status", default: 0, null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role"], name: "index_users_on_role"
    t.index ["status"], name: "index_users_on_status"
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
  add_foreign_key "tags", "users"
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
@layer properties{@supports (((-webkit-hyphens:none)) and (not (margin-trim:inline))) or ((-moz-orient:inline) and (not (color:rgb(from red r g b)))){*,:before,:after,::backdrop{--tw-rotate-x:initial;--tw-rotate-y:initial;--tw-rotate-z:initial;--tw-skew-x:initial;--tw-skew-y:initial;--tw-space-y-reverse:0;--tw-space-x-reverse:0;--tw-divide-y-reverse:0;--tw-border-style:solid;--tw-leading:initial;--tw-font-weight:initial;--tw-tracking:initial;--tw-shadow:0 0 #0000;--tw-shadow-color:initial;--tw-shadow-alpha:100%;--tw-inset-shadow:0 0 #0000;--tw-inset-shadow-color:initial;--tw-inset-shadow-alpha:100%;--tw-ring-color:initial;--tw-ring-shadow:0 0 #0000;--tw-inset-ring-color:initial;--tw-inset-ring-shadow:0 0 #0000;--tw-ring-inset:initial;--tw-ring-offset-width:0px;--tw-ring-offset-color:#fff;--tw-ring-offset-shadow:0 0 #0000;--tw-outline-style:solid;--tw-blur:initial;--tw-brightness:initial;--tw-contrast:initial;--tw-grayscale:initial;--tw-hue-rotate:initial;--tw-invert:initial;--tw-opacity:initial;--tw-saturate:initial;--tw-sepia:initial;--tw-drop-shadow:initial;--tw-drop-shadow-color:initial;--tw-drop-shadow-alpha:100%;--tw-drop-shadow-size:initial}}}@layer theme{:root,:host{--font-sans:ui-sans-serif,system-ui,sans-serif,"Apple Color Emoji","Segoe UI Emoji","Segoe UI Symbol","Noto Color Emoji";--font-mono:ui-monospace,SFMono-Regular,Menlo,Monaco,Consolas,"Liberation Mono","Courier New",monospace;--color-red-50:oklch(97.1% .013 17.38);--color-red-100:oklch(93.6% .032 17.717);--color-red-200:oklch(88.5% .062 18.334);--color-red-300:oklch(80.8% .114 19.571);--color-red-500:oklch(63.7% .237 25.331);--color-red-600:oklch(57.7% .245 27.325);--color-red-700:oklch(50.5% .213 27.518);--color-red-800:oklch(44.4% .177 26.899);--color-orange-300:oklch(83.7% .128 66.29);--color-orange-600:oklch(64.6% .222 41.116);--color-orange-800:oklch(47% .157 37.304);--color-yellow-100:oklch(97.3% .071 103.193);--color-yellow-800:oklch(47.6% .114 61.907);--color-green-100:oklch(96.2% .044 156.743);--color-green-300:oklch(87.1% .15 154.449);--color-green-400:oklch(79.2% .209 151.711);--color-green-500:oklch(72.3% .219 149.579);--color-green-600:oklch(62.7% .194 149.214);--color-green-700:oklch(52.7% .154 150.069);--color-green-800:oklch(44.8% .119 151.328);--color-emerald-900:oklch(37.8% .077 168.94);--color-blue-50:oklch(97% .014 254.604);--color-blue-100:oklch(93.2% .032 255.585);--color-blue-200:oklch(88.2% .059 254.128);--color-blue-300:oklch(80.9% .105 251.813);--color-blue-400:oklch(70.7% .165 254.624);--color-blue-500:oklch(62.3% .214 259.815);--color-blue-600:oklch(54.6% .245 262.881);--color-blue-700:oklch(48.8% .243 264.376);--color-blue-800:oklch(42.4% .199 265.638);--color-indigo-900:oklch(35.9% .144 278.697);--color-purple-500:oklch(62.7% .265 303.9);--color-purple-600:oklch(55.8% .288 302.321);--color-gray-50:oklch(98.5% .002 247.839);--color-gray-100:oklch(96.7% .003 264.542);--color-gray-200:oklch(92.8% .006 264.531);--color-gray-300:oklch(87.2% .01 258.338);--color-gray-400:oklch(70.7% .022 261.325);--color-gray-500:oklch(55.1% .027 264.364);--color-gray-600:oklch(44.6% .03 256.802);--color-gray-700:oklch(37.3% .034 259.733);--color-gray-800:oklch(27.8% .033 256.848);--color-gray-900:oklch(21% .034 264.665);--color-stone-900:oklch(21.6% .006 56.043);--color-black:#000;--color-white:#fff;--spacing:.25rem;--container-xs:20rem;--container-2xl:42rem;--container-3xl:48rem;--container-4xl:56rem;--container-5xl:64rem;--container-6xl:72rem;--text-xs:.75rem;--text-xs--line-height:calc(1/.75);--text-sm:.875rem;--text-sm--line-height:calc(1.25/.875);--text-base:1rem;--text-base--line-height:calc(1.5/1);--text-lg:1.125rem;--text-lg--line-height:calc(1.75/1.125);--text-xl:1.25rem;--text-xl--line-height:calc(1.75/1.25);--text-2xl:1.5rem;--text-2xl--line-height:calc(2/1.5);--text-3xl:1.875rem;--text-3xl--line-height:calc(2.25/1.875);--text-4xl:2.25rem;--text-4xl--line-height:calc(2.5/2.25);--text-5xl:3rem;--text-5xl--line-height:1;--font-weight-medium:500;--font-weight-semibold:600;--font-weight-bold:700;--font-weight-extrabold:800;--tracking-wider:.05em;--leading-relaxed:1.625;--radius-md:.375rem;--radius-lg:.5rem;--default-transition-duration:.15s;--default-transition-timing-function:cubic-bezier(.4,0,.2,1);--default-font-family:var(--font-sans);--default-mono-font-family:var(--font-mono)}}@layer base{*,:after,:before,::backdrop{box-sizing:border-box;border:0 solid;margin:0;padding:0}::file-selector-button{box-sizing:border-box;border:0 solid;margin:0;padding:0}html,:host{-webkit-text-size-adjust:100%;tab-size:4;line-height:1.5;font-family:var(--default-font-family,ui-sans-serif,system-ui,sans-serif,"Apple Color Emoji","Segoe UI Emoji","Segoe UI Symbol","Noto Color Emoji");font-feature-settings:var(--default-font-feature-settings,normal);font-variation-settings:var(--default-font-variation-settings,normal);-webkit-tap-highlight-color:transparent}hr{height:0;color:inherit;border-top-width:1px}abbr:where([title]){-webkit-text-decoration:underline dotted;text-decoration:underline dotted}h1,h2,h3,h4,h5,h6{font-size:inherit;font-weight:inherit}a{color:inherit;-webkit-text-decoration:inherit;-webkit-text-decoration:inherit;-webkit-text-decoration:inherit;text-decoration:inherit}b,strong{font-weight:bolder}code,kbd,samp,pre{font-family:var(--default-mono-font-family,ui-monospace,SFMono-Regular,Menlo,Monaco,Consolas,"Liberation Mono","Courier New",monospace);font-feature-settings:var(--default-mono-font-feature-settings,normal);font-variation-settings:var(--default-mono-font-variation-settings,normal);font-size:1em}small{font-size:80%}sub,sup{vertical-align:baseline;font-size:75%;line-height:0;position:relative}sub{bottom:-.25em}sup{top:-.5em}table{text-indent:0;border-color:inherit;border-collapse:collapse}:-moz-focusring{outline:auto}progress{vertical-align:baseline}summary{display:list-item}ol,ul,menu{list-style:none}img,svg,video,canvas,audio,iframe,embed,object{vertical-align:middle;display:block}img,video{max-width:100%;height:auto}button,input,select,optgroup,textarea{font:inherit;font-feature-settings:inherit;font-variation-settings:inherit;letter-spacing:inherit;color:inherit;opacity:1;background-color:#0000;border-radius:0}::file-selector-button{font:inherit;font-feature-settings:inherit;font-variation-settings:inherit;letter-spacing:inherit;color:inherit;opacity:1;background-color:#0000;border-radius:0}:where(select:is([multiple],[size])) optgroup{font-weight:bolder}:where(select:is([multiple],[size])) optgroup option{padding-inline-start:20px}::file-selector-button{margin-inline-end:4px}::placeholder{opacity:1}@supports (not ((-webkit-appearance:-apple-pay-button))) or (contain-intrinsic-size:1px){::placeholder{color:currentColor}@supports (color:color-mix(in lab, red, red)){::placeholder{color:color-mix(in oklab,currentcolor 50%,transparent)}}}textarea{resize:vertical}::-webkit-search-decoration{-webkit-appearance:none}::-webkit-date-and-time-value{min-height:1lh;text-align:inherit}::-webkit-datetime-edit{display:inline-flex}::-webkit-datetime-edit-fields-wrapper{padding:0}::-webkit-datetime-edit{padding-block:0}::-webkit-datetime-edit-year-field{padding-block:0}::-webkit-datetime-edit-month-field{padding-block:0}::-webkit-datetime-edit-day-field{padding-block:0}::-webkit-datetime-edit-hour-field{padding-block:0}::-webkit-datetime-edit-minute-field{padding-block:0}::-webkit-datetime-edit-second-field{padding-block:0}::-webkit-datetime-edit-millisecond-field{padding-block:0}::-webkit-datetime-edit-meridiem-field{padding-block:0}::-webkit-calendar-picker-indicator{line-height:1}:-moz-ui-invalid{box-shadow:none}button,input:where([type=button],[type=reset],[type=submit]){appearance:button}::file-selector-button{appearance:button}::-webkit-inner-spin-button{height:auto}::-webkit-outer-spin-button{height:auto}[hidden]:where(:not([hidden=until-found])){display:none!important}}@layer components;@layer utilities{.pointer-events-none{pointer-events:none}.visible{visibility:visible}.sr-only{clip-path:inset(50%);white-space:nowrap;border-width:0;width:1px;height:1px;margin:-1px;padding:0;position:absolute;overflow:hidden}.absolute{position:absolute}.fixed{position:fixed}.relative{position:relative}.static{position:static}.inset-0{inset:calc(var(--spacing)*0)}.top-0{top:calc(var(--spacing)*0)}.bottom-0{bottom:calc(var(--spacing)*0)}.left-1{left:calc(var(--spacing)*1)}.left-1\/2{left:50%}.z-50{z-index:50}.float-left{float:left}.float-right{float:right}.container{width:100%}@media (min-width:40rem){.container{max-width:40rem}}@media (min-width:48rem){.container{max-width:48rem}}@media (min-width:64rem){.container{max-width:64rem}}@media (min-width:80rem){.container{max-width:80rem}}@media (min-width:96rem){.container{max-width:96rem}}.mx-2{margin-inline:calc(var(--spacing)*2)}.mx-4{margin-inline:calc(var(--spacing)*4)}.mx-8{margin-inline:calc(var(--spacing)*8)}.mx-auto{margin-inline:auto}.my-16{margin-block:calc(var(--spacing)*16)}.mt-1{margin-top:calc(var(--spacing)*1)}.mt-2{margin-top:calc(var(--spacing)*2)}.mt-3{margin-top:calc(var(--spacing)*3)}.mt-4{margin-top:calc(var(--spacing)*4)}.mt-8{margin-top:calc(var(--spacing)*8)}.mt-12{margin-top:calc(var(--spacing)*12)}.mr-2{margin-right:calc(var(--spacing)*2)}.mr-3{margin-right:calc(var(--spacing)*3)}.mb-1{margin-bottom:calc(var(--spacing)*1)}.mb-2{margin-bottom:calc(var(--spacing)*2)}.mb-3{margin-bottom:calc(var(--spacing)*3)}.mb-4{margin-bottom:calc(var(--spacing)*4)}.mb-6{margin-bottom:calc(var(--spacing)*6)}.mb-8{margin-bottom:calc(var(--spacing)*8)}.mb-12{margin-bottom:calc(var(--spacing)*12)}.ml-2{margin-left:calc(var(--spacing)*2)}.ml-4{margin-left:calc(var(--spacing)*4)}.ml-6{margin-left:calc(var(--spacing)*6)}.ml-auto{margin-left:auto}.line-clamp-2{-webkit-line-clamp:2;-webkit-box-orient:vertical;display:-webkit-box;overflow:hidden}.block{display:block}.flex{display:flex}.grid{display:grid}.hidden{display:none}.inline{display:inline}.inline-block{display:inline-block}.inline-flex{display:inline-flex}.table{display:table}.h-4{height:calc(var(--spacing)*4)}.h-6{height:calc(var(--spacing)*6)}.h-8{height:calc(var(--spacing)*8)}.h-12{height:calc(var(--spacing)*12)}.h-20{height:calc(var(--spacing)*20)}.h-24{height:calc(var(--spacing)*24)}.h-32{height:calc(var(--spacing)*32)}.h-48{height:calc(var(--spacing)*48)}.h-64{height:calc(var(--spacing)*64)}.h-full{height:100%}.h-screen{height:100vh}.min-h-screen{min-height:100vh}.w-1{width:calc(var(--spacing)*1)}.w-1\/2{width:50%}.w-4{width:calc(var(--spacing)*4)}.w-6{width:calc(var(--spacing)*6)}.w-8{width:calc(var(--spacing)*8)}.w-12{width:calc(var(--spacing)*12)}.w-20{width:calc(var(--spacing)*20)}.w-24{width:calc(var(--spacing)*24)}.w-32{width:calc(var(--spacing)*32)}.w-64{width:calc(var(--spacing)*64)}.w-96{width:calc(var(--spacing)*96)}.w-\[1px\]{width:1px}.w-full{width:100%}.max-w-2xl{max-width:var(--container-2xl)}.max-w-3xl{max-width:var(--container-3xl)}.max-w-4xl{max-width:var(--container-4xl)}.max-w-5xl{max-width:var(--container-5xl)}.max-w-6xl{max-width:var(--container-6xl)}.max-w-xs{max-width:var(--container-xs)}.flex-1{flex:1}.flex-shrink-0{flex-shrink:0}.flex-grow{flex-grow:1}.border-collapse{border-collapse:collapse}.transform{transform:var(--tw-rotate-x,)var(--tw-rotate-y,)var(--tw-rotate-z,)var(--tw-skew-x,)var(--tw-skew-y,)}.cursor-pointer{cursor:pointer}.list-disc{list-style-type:disc}.grid-cols-1{grid-template-columns:repeat(1,minmax(0,1fr))}.grid-cols-2{grid-template-columns:repeat(2,minmax(0,1fr))}.flex-col{flex-direction:column}.flex-wrap{flex-wrap:wrap}.items-baseline{align-items:baseline}.items-center{align-items:center}.items-start{align-items:flex-start}.justify-between{justify-content:space-between}.justify-center{justify-content:center}.justify-end{justify-content:flex-end}.gap-1{gap:calc(var(--spacing)*1)}.gap-2{gap:calc(var(--spacing)*2)}.gap-3{gap:calc(var(--spacing)*3)}.gap-4{gap:calc(var(--spacing)*4)}.gap-5{gap:calc(var(--spacing)*5)}.gap-6{gap:calc(var(--spacing)*6)}:where(.space-y-1>:not(:last-child)){--tw-space-y-reverse:0;margin-block-start:calc(calc(var(--spacing)*1)*var(--tw-space-y-reverse));margin-block-end:calc(calc(var(--spacing)*1)*calc(1 - var(--tw-space-y-reverse)))}:where(.space-y-2>:not(:last-child)){--tw-space-y-reverse:0;margin-block-start:calc(calc(var(--spacing)*2)*var(--tw-space-y-reverse));margin-block-end:calc(calc(var(--spacing)*2)*calc(1 - var(--tw-space-y-reverse)))}:where(.space-y-3>:not(:last-child)){--tw-space-y-reverse:0;margin-block-start:calc(calc(var(--spacing)*3)*var(--tw-space-y-reverse));margin-block-end:calc(calc(var(--spacing)*3)*calc(1 - var(--tw-space-y-reverse)))}:where(.space-y-4>:not(:last-child)){--tw-space-y-reverse:0;margin-block-start:calc(calc(var(--spacing)*4)*var(--tw-space-y-reverse));margin-block-end:calc(calc(var(--spacing)*4)*calc(1 - var(--tw-space-y-reverse)))}:where(.space-y-6>:not(:last-child)){--tw-space-y-reverse:0;margin-block-start:calc(calc(var(--spacing)*6)*var(--tw-space-y-reverse));margin-block-end:calc(calc(var(--spacing)*6)*calc(1 - var(--tw-space-y-reverse)))}:where(.space-y-8>:not(:last-child)){--tw-space-y-reverse:0;margin-block-start:calc(calc(var(--spacing)*8)*var(--tw-space-y-reverse));margin-block-end:calc(calc(var(--spacing)*8)*calc(1 - var(--tw-space-y-reverse)))}:where(.space-x-2>:not(:last-child)){--tw-space-x-reverse:0;margin-inline-start:calc(calc(var(--spacing)*2)*var(--tw-space-x-reverse));margin-inline-end:calc(calc(var(--spacing)*2)*calc(1 - var(--tw-space-x-reverse)))}:where(.divide-y>:not(:last-child)){--tw-divide-y-reverse:0;border-bottom-style:var(--tw-border-style);border-top-style:var(--tw-border-style);border-top-width:calc(1px*var(--tw-divide-y-reverse));border-bottom-width:calc(1px*calc(1 - var(--tw-divide-y-reverse)))}:where(.divide-gray-200>:not(:last-child)){border-color:var(--color-gray-200)}.truncate{text-overflow:ellipsis;white-space:nowrap;overflow:hidden}.overflow-hidden{overflow:hidden}.rounded{border-radius:.25rem}.rounded-full{border-radius:3.40282e38px}.rounded-lg{border-radius:var(--radius-lg)}.rounded-md{border-radius:var(--radius-md)}.border{border-style:var(--tw-border-style);border-width:1px}.border-0{border-style:var(--tw-border-style);border-width:0}.border-2{border-style:var(--tw-border-style);border-width:2px}.border-t{border-top-style:var(--tw-border-style);border-top-width:1px}.border-b{border-bottom-style:var(--tw-border-style);border-bottom-width:1px}.border-blue-200{border-color:var(--color-blue-200)}.border-gray-100{border-color:var(--color-gray-100)}.border-gray-200{border-color:var(--color-gray-200)}.border-gray-300{border-color:var(--color-gray-300)}.border-gray-400{border-color:var(--color-gray-400)}.border-gray-500{border-color:var(--color-gray-500)}.border-gray-600{border-color:var(--color-gray-600)}.border-green-300{border-color:var(--color-green-300)}.border-green-400{border-color:var(--color-green-400)}.border-orange-300{border-color:var(--color-orange-300)}.border-red-200{border-color:var(--color-red-200)}.border-red-300{border-color:var(--color-red-300)}.bg-black{background-color:var(--color-black)}.bg-blue-50{background-color:var(--color-blue-50)}.bg-blue-100{background-color:var(--color-blue-100)}.bg-blue-300{background-color:var(--color-blue-300)}.bg-blue-500{background-color:var(--color-blue-500)}.bg-emerald-900{background-color:var(--color-emerald-900)}.bg-gray-50{background-color:var(--color-gray-50)}.bg-gray-100{background-color:var(--color-gray-100)}.bg-gray-200{background-color:var(--color-gray-200)}.bg-gray-300{background-color:var(--color-gray-300)}.bg-gray-400{background-color:var(--color-gray-400)}.bg-gray-500{background-color:var(--color-gray-500)}.bg-gray-700{background-color:var(--color-gray-700)}.bg-gray-800{background-color:var(--color-gray-800)}.bg-green-100{background-color:var(--color-green-100)}.bg-green-500{background-color:var(--color-green-500)}.bg-indigo-900{background-color:var(--color-indigo-900)}.bg-purple-500{background-color:var(--color-purple-500)}.bg-red-50{background-color:var(--color-red-50)}.bg-red-100{background-color:var(--color-red-100)}.bg-red-500{background-color:var(--color-red-500)}.bg-stone-900{background-color:var(--color-stone-900)}.bg-white{background-color:var(--color-white)}.bg-yellow-100{background-color:var(--color-yellow-100)}.object-cover{object-fit:cover}.p-2{padding:calc(var(--spacing)*2)}.p-3{padding:calc(var(--spacing)*3)}.p-4{padding:calc(var(--spacing)*4)}.p-6{padding:calc(var(--spacing)*6)}.p-8{padding:calc(var(--spacing)*8)}.px-2{padding-inline:calc(var(--spacing)*2)}.px-2\.5{padding-inline:calc(var(--spacing)*2.5)}.px-3{padding-inline:calc(var(--spacing)*3)}.px-4{padding-inline:calc(var(--spacing)*4)}.px-6{padding-inline:calc(var(--spacing)*6)}.px-8{padding-inline:calc(var(--spacing)*8)}.py-0{padding-block:calc(var(--spacing)*0)}.py-0\.5{padding-block:calc(var(--spacing)*.5)}.py-1{padding-block:calc(var(--spacing)*1)}.py-2{padding-block:calc(var(--spacing)*2)}.py-3{padding-block:calc(var(--spacing)*3)}.py-4{padding-block:calc(var(--spacing)*4)}.py-8{padding-block:calc(var(--spacing)*8)}.py-10{padding-block:calc(var(--spacing)*10)}.py-16{padding-block:calc(var(--spacing)*16)}.pt-8{padding-top:calc(var(--spacing)*8)}.pr-5{padding-right:calc(var(--spacing)*5)}.pb-2{padding-bottom:calc(var(--spacing)*2)}.pb-3{padding-bottom:calc(var(--spacing)*3)}.pb-4{padding-bottom:calc(var(--spacing)*4)}.pl-5{padding-left:calc(var(--spacing)*5)}.text-center{text-align:center}.text-left{text-align:left}.text-right{text-align:right}.text-2xl{font-size:var(--text-2xl);line-height:var(--tw-leading,var(--text-2xl--line-height))}.text-3xl{font-size:var(--text-3xl);line-height:var(--tw-leading,var(--text-3xl--line-height))}.text-4xl{font-size:var(--text-4xl);line-height:var(--tw-leading,var(--text-4xl--line-height))}.text-5xl{font-size:var(--text-5xl);line-height:var(--tw-leading,var(--text-5xl--line-height))}.text-base{font-size:var(--text-base);line-height:var(--tw-leading,var(--text-base--line-height))}.text-lg{font-size:var(--text-lg);line-height:var(--tw-leading,var(--text-lg--line-height))}.text-sm{font-size:var(--text-sm);line-height:var(--tw-leading,var(--text-sm--line-height))}.text-xl{font-size:var(--text-xl);line-height:var(--tw-leading,var(--text-xl--line-height))}.text-xs{font-size:var(--text-xs);line-height:var(--tw-leading,var(--text-xs--line-height))}.leading-relaxed{--tw-leading:var(--leading-relaxed);line-height:var(--leading-relaxed)}.font-bold{--tw-font-weight:var(--font-weight-bold);font-weight:var(--font-weight-bold)}.font-extrabold{--tw-font-weight:var(--font-weight-extrabold);font-weight:var(--font-weight-extrabold)}.font-medium{--tw-font-weight:var(--font-weight-medium);font-weight:var(--font-weight-medium)}.font-semibold{--tw-font-weight:var(--font-weight-semibold);font-weight:var(--font-weight-semibold)}.tracking-wider{--tw-tracking:var(--tracking-wider);letter-spacing:var(--tracking-wider)}.whitespace-nowrap{white-space:nowrap}.text-blue-400{color:var(--color-blue-400)}.text-blue-500{color:var(--color-blue-500)}.text-blue-600{color:var(--color-blue-600)}.text-blue-800{color:var(--color-blue-800)}.text-gray-200{color:var(--color-gray-200)}.text-gray-300{color:var(--color-gray-300)}.text-gray-400{color:var(--color-gray-400)}.text-gray-500{color:var(--color-gray-500)}.text-gray-600{color:var(--color-gray-600)}.text-gray-700{color:var(--color-gray-700)}.text-gray-800{color:var(--color-gray-800)}.text-gray-900{color:var(--color-gray-900)}.text-green-600{color:var(--color-green-600)}.text-green-700{color:var(--color-green-700)}.text-green-800{color:var(--color-green-800)}.text-orange-600{color:var(--color-orange-600)}.text-red-500{color:var(--color-red-500)}.text-red-600{color:var(--color-red-600)}.text-red-700{color:var(--color-red-700)}.text-red-800{color:var(--color-red-800)}.text-white{color:var(--color-white)}.text-yellow-800{color:var(--color-yellow-800)}.uppercase{text-transform:uppercase}.italic{font-style:italic}.underline{text-decoration-line:underline}.placeholder-gray-400::placeholder{color:var(--color-gray-400)}.shadow-md{--tw-shadow:0 4px 6px -1px var(--tw-shadow-color,#0000001a),0 2px 4px -2px var(--tw-shadow-color,#0000001a);box-shadow:var(--tw-inset-shadow),var(--tw-inset-ring-shadow),var(--tw-ring-offset-shadow),var(--tw-ring-shadow),var(--tw-shadow)}.shadow-sm{--tw-shadow:0 1px 3px 0 var(--tw-shadow-color,#0000001a),0 1px 2px -1px var(--tw-shadow-color,#0000001a);box-shadow:var(--tw-inset-shadow),var(--tw-inset-ring-shadow),var(--tw-ring-offset-shadow),var(--tw-ring-shadow),var(--tw-shadow)}.outline{outline-style:var(--tw-outline-style);outline-width:1px}.filter{filter:var(--tw-blur,)var(--tw-brightness,)var(--tw-contrast,)var(--tw-grayscale,)var(--tw-hue-rotate,)var(--tw-invert,)var(--tw-saturate,)var(--tw-sepia,)var(--tw-drop-shadow,)}.transition{transition-property:color,background-color,border-color,outline-color,text-decoration-color,fill,stroke,--tw-gradient-from,--tw-gradient-via,--tw-gradient-to,opacity,box-shadow,transform,translate,scale,rotate,filter,-webkit-backdrop-filter,backdrop-filter,display,content-visibility,overlay,pointer-events;transition-timing-function:var(--tw-ease,var(--default-transition-timing-function));transition-duration:var(--tw-duration,var(--default-transition-duration))}.transition-colors{transition-property:color,background-color,border-color,outline-color,text-decoration-color,fill,stroke,--tw-gradient-from,--tw-gradient-via,--tw-gradient-to;transition-timing-function:var(--tw-ease,var(--default-transition-timing-function));transition-duration:var(--tw-duration,var(--default-transition-duration))}.peer-checked\:ring-2:is(:where(.peer):checked~*){--tw-ring-shadow:var(--tw-ring-inset,)0 0 0 calc(2px + var(--tw-ring-offset-width))var(--tw-ring-color,currentcolor);box-shadow:var(--tw-inset-shadow),var(--tw-inset-ring-shadow),var(--tw-ring-offset-shadow),var(--tw-ring-shadow),var(--tw-shadow)}.peer-checked\:ring-blue-400:is(:where(.peer):checked~*){--tw-ring-color:var(--color-blue-400)}.file\:mr-4::file-selector-button{margin-right:calc(var(--spacing)*4)}.file\:rounded::file-selector-button{border-radius:.25rem}.file\:border-0::file-selector-button{border-style:var(--tw-border-style);border-width:0}.file\:bg-blue-50::file-selector-button{background-color:var(--color-blue-50)}.file\:px-4::file-selector-button{padding-inline:calc(var(--spacing)*4)}.file\:py-2::file-selector-button{padding-block:calc(var(--spacing)*2)}.file\:text-sm::file-selector-button{font-size:var(--text-sm);line-height:var(--tw-leading,var(--text-sm--line-height))}.file\:font-semibold::file-selector-button{--tw-font-weight:var(--font-weight-semibold);font-weight:var(--font-weight-semibold)}.file\:text-blue-700::file-selector-button{color:var(--color-blue-700)}.last\:border-b-0:last-child{border-bottom-style:var(--tw-border-style);border-bottom-width:0}@media (hover:hover){.hover\:overflow-y-auto:hover{overflow-y:auto}.hover\:border-gray-400:hover{border-color:var(--color-gray-400)}.hover\:bg-blue-200:hover{background-color:var(--color-blue-200)}.hover\:bg-blue-600:hover{background-color:var(--color-blue-600)}.hover\:bg-gray-50:hover{background-color:var(--color-gray-50)}.hover\:bg-gray-100:hover{background-color:var(--color-gray-100)}.hover\:bg-gray-200:hover{background-color:var(--color-gray-200)}.hover\:bg-gray-600:hover{background-color:var(--color-gray-600)}.hover\:text-blue-600:hover{color:var(--color-blue-600)}.hover\:text-blue-800:hover{color:var(--color-blue-800)}.hover\:text-gray-100:hover{color:var(--color-gray-100)}.hover\:text-gray-300:hover{color:var(--color-gray-300)}.hover\:text-gray-600:hover{color:var(--color-gray-600)}.hover\:text-gray-700:hover{color:var(--color-gray-700)}.hover\:text-gray-800:hover{color:var(--color-gray-800)}.hover\:text-green-800:hover{color:var(--color-green-800)}.hover\:text-orange-800:hover{color:var(--color-orange-800)}.hover\:text-red-800:hover{color:var(--color-red-800)}.hover\:text-white:hover{color:var(--color-white)}.hover\:file\:bg-blue-100:hover::file-selector-button{background-color:var(--color-blue-100)}}.focus\:border-\[1px\]:focus{border-style:var(--tw-border-style);border-width:1px}.focus\:border-gray-300:focus{border-color:var(--color-gray-300)}.focus\:border-gray-400:focus{border-color:var(--color-gray-400)}.focus\:ring-0:focus{--tw-ring-shadow:var(--tw-ring-inset,)0 0 0 calc(0px + var(--tw-ring-offset-width))var(--tw-ring-color,currentcolor);box-shadow:var(--tw-inset-shadow),var(--tw-inset-ring-shadow),var(--tw-ring-offset-shadow),var(--tw-ring-shadow),var(--tw-shadow)}.focus\:ring-1:focus{--tw-ring-shadow:var(--tw-ring-inset,)0 0 0 calc(1px + var(--tw-ring-offset-width))var(--tw-ring-color,currentcolor);box-shadow:var(--tw-inset-shadow),var(--tw-inset-ring-shadow),var(--tw-ring-offset-shadow),var(--tw-ring-shadow),var(--tw-shadow)}.focus\:ring-blue-500:focus{--tw-ring-color:var(--color-blue-500)}.focus\:ring-gray-400:focus{--tw-ring-color:var(--color-gray-400)}.focus\:ring-gray-500:focus{--tw-ring-color:var(--color-gray-500)}.focus\:outline-none:focus{--tw-outline-style:none;outline-style:none}@media (min-width:48rem){.md\:grid-cols-2{grid-template-columns:repeat(2,minmax(0,1fr))}.md\:grid-cols-3{grid-template-columns:repeat(3,minmax(0,1fr))}}@media (min-width:64rem){.lg\:grid-cols-3{grid-template-columns:repeat(3,minmax(0,1fr))}}}.layout-switcher.mode-split .text-area,.layout-switcher.mode-split .preview-area{flex:1;display:block}.layout-switcher.mode-split .original-preview-area{display:none}.layout-switcher.mode-text-only .text-area{flex:1;display:block}.layout-switcher.mode-text-only .preview-area,.layout-switcher.mode-text-only .original-preview-area,.layout-switcher.mode-text-only .layout-divider,.layout-switcher.mode-preview-only .text-area{display:none}.layout-switcher.mode-preview-only .preview-area{flex:1;display:block}.layout-switcher.mode-preview-only .original-preview-area,.layout-switcher.mode-preview-only .layout-divider{display:none}.layout-switcher.mode-original-preview .text-area{flex:1;display:block}.layout-switcher.mode-original-preview .preview-area{display:none}.layout-switcher.mode-original-preview .original-preview-area{flex:1;display:block}.layout-switcher.mode-original-preview .layout-divider{display:block}.layout-buttons button{cursor:pointer;background:#fff;border:1px solid #ccc;border-radius:4px;min-width:32px;height:32px;padding:4px 8px;font-size:16px}.layout-buttons button:hover{background:#f3f4f6}.layout-buttons button.active{background:#e5e7eb;border-color:#6b7280}.layout-switcher{width:100%;height:100%}.default-theme .theme-header{border-bottom:1px solid #e5e7eb;color:#374151!important;background-color:#f9fafb!important}.default-theme .theme-header a{color:#374151!important}.default-theme .theme-header a:hover{color:#1f2937!important}.default-theme .theme-header button{color:#374151!important}.default-theme .theme-header button:hover{color:#1f2937!important}.default-theme .theme-footer{color:#374151!important;background-color:#f9fafb!important;border-top:1px solid #e5e7eb!important}.default-theme .theme-footer a{color:#374151!important}.default-theme .theme-footer a:hover{color:#1f2937!important}.slate-theme .blog-title{color:#222b45!important}.slate-theme .theme-header,.slate-theme .theme-footer{color:#e5e7eb!important;background-color:#222b45!important}.forest-theme .blog-title{color:#1b4332!important}.forest-theme .theme-header,.forest-theme .theme-footer{color:#e5e7eb!important;background-color:#1b4332!important}.maroon-theme .blog-title{color:#3a0a0a!important}.maroon-theme .theme-header,.maroon-theme .theme-footer{color:#e5e7eb!important;background-color:#3a0a0a!important}.midnight-theme .blog-title{color:#0a1a2f!important}.midnight-theme .theme-header,.midnight-theme .theme-footer{color:#e5e7eb!important;background-color:#0a1a2f!important}[data-markdown-preview-target=preview] img{object-fit:contain;border-radius:4px;width:100%;height:auto;margin:10px 0}.article-content img{object-fit:contain;object-fit:contain;border-radius:4px;max-width:100%;height:auto;max-height:500px;margin:15px auto;display:block;box-shadow:0 2px 8px #0000001a}.tab-container{margin:20px 0}.tab-buttons{border-bottom:2px solid #ddd;margin-bottom:20px;display:flex}.tab-button{cursor:pointer;background:#f5f5f5;border:none;border-top:2px solid #0000;margin-right:2px;padding:10px 20px}.tab-button.active{background:#fff;border-top-color:#007bff;font-weight:700}.tab-content{display:none}.tab-content.active{display:block}@property --tw-rotate-x{syntax:"*";inherits:false}@property --tw-rotate-y{syntax:"*";inherits:false}@property --tw-rotate-z{syntax:"*";inherits:false}@property --tw-skew-x{syntax:"*";inherits:false}@property --tw-skew-y{syntax:"*";inherits:false}@property --tw-space-y-reverse{syntax:"*";inherits:false;initial-value:0}@property --tw-space-x-reverse{syntax:"*";inherits:false;initial-value:0}@property --tw-divide-y-reverse{syntax:"*";inherits:false;initial-value:0}@property --tw-border-style{syntax:"*";inherits:false;initial-value:solid}@property --tw-leading{syntax:"*";inherits:false}@property --tw-font-weight{syntax:"*";inherits:false}@property --tw-tracking{syntax:"*";inherits:false}@property --tw-shadow{syntax:"*";inherits:false;initial-value:0 0 #0000}@property --tw-shadow-color{syntax:"*";inherits:false}@property --tw-shadow-alpha{syntax:"<percentage>";inherits:false;initial-value:100%}@property --tw-inset-shadow{syntax:"*";inherits:false;initial-value:0 0 #0000}@property --tw-inset-shadow-color{syntax:"*";inherits:false}@property --tw-inset-shadow-alpha{syntax:"<percentage>";inherits:false;initial-value:100%}@property --tw-ring-color{syntax:"*";inherits:false}@property --tw-ring-shadow{syntax:"*";inherits:false;initial-value:0 0 #0000}@property --tw-inset-ring-color{syntax:"*";inherits:false}@property --tw-inset-ring-shadow{syntax:"*";inherits:false;initial-value:0 0 #0000}@property --tw-ring-inset{syntax:"*";inherits:false}@property --tw-ring-offset-width{syntax:"<length>";inherits:false;initial-value:0}@property --tw-ring-offset-color{syntax:"*";inherits:false;initial-value:#fff}@property --tw-ring-offset-shadow{syntax:"*";inherits:false;initial-value:0 0 #0000}@property --tw-outline-style{syntax:"*";inherits:false;initial-value:solid}@property --tw-blur{syntax:"*";inherits:false}@property --tw-brightness{syntax:"*";inherits:false}@property --tw-contrast{syntax:"*";inherits:false}@property --tw-grayscale{syntax:"*";inherits:false}@property --tw-hue-rotate{syntax:"*";inherits:false}@property --tw-invert{syntax:"*";inherits:false}@property --tw-opacity{syntax:"*";inherits:false}@property --tw-saturate{syntax:"*";inherits:false}@property --tw-sepia{syntax:"*";inherits:false}@property --tw-drop-shadow{syntax:"*";inherits:false}@property --tw-drop-shadow-color{syntax:"*";inherits:false}@property --tw-drop-shadow-alpha{syntax:"<percentage>";inherits:false;initial-value:100%}@property --tw-drop-shadow-size{syntax:"*";inherits:false}```

## File: `app/assets/stylesheets/application.css`

```
.flash-message {
  transition: opacity 0.3s ease-out;
}

.btn-unified {
  padding: 0.45rem 0.9rem;
  border: 1px solid #ccc;
  background-color: #f8f8f8;
  color: #2f2f2f;
  border-radius: 6px;
  font-size: 0.85rem;
  font-weight: 500;
  cursor: pointer;
  display: inline-block;
  text-decoration: none;
  transition:
    background-color 0.2s ease,
    border-color 0.2s ease;
}

.btn-unified:hover {
  background-color: #efefef;
  border-color: #bbb;
}

.btn-unified:active {
  background-color: #e5e5e5;
}

/* サムネイル画像 */
.line-clamp-2 {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.default-thumbnail {
  width: 100%;
  height: 12rem; /* h-48 相当 */
  background-color: #f6f8fa;
  border: 1px solid #e1e5e9;
  border-radius: 8px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 14px;
  color: #6e7781;
  text-align: center;
  padding: 20px;
  font-weight: 500;
}

.tile-article {
  background: white;
  border-radius: 8px;
  overflow: hidden;
  transition:
    transform 0.2s,
    box-shadow 0.2s;
}

.tile-article:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
}

.list-article {
  transition: background-color 0.2s;
}

.list-article:hover {
  background-color: #f9fafb;
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
  background: #fdf6e3; /* 薄いクリーム色 */
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
  background: #fdf6e3; /* 薄いクリーム色 */
  border-radius: 2px;
  padding: 3px 4px;
  font-family: "SF Mono", Monaco, monospace;
  font-size: 16px;
}
```

## File: `app/assets/stylesheets/syntax-highlighting.css`

```
.highlight table td {
  padding: 5px;
}
.highlight table pre {
  margin: 0;
}

.highlight,
.highlight .w {
  color: #24292f;
  background-color: #faf9f7; /* 薄いクリーム色 */
}

.highlight pre,
.markdown-body pre {
  padding: 16px;
  overflow: auto;
  font-size: 85%;
  line-height: 1.45;
  color: #1f2328;
  background-color: #fdf6e3; /* 薄いクリーム色 */
  border-radius: 6px;
}

.highlight .k,
.highlight .kd,
.highlight .kn,
.highlight .kp,
.highlight .kr,
.highlight .kt,
.highlight .kv {
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
.highlight .l,
.highlight .ld,
.highlight .m,
.highlight .mb,
.highlight .mf,
.highlight .mh,
.highlight .mi,
.highlight .il,
.highlight .mo,
.highlight .mx {
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
.highlight .nv,
.highlight .vc,
.highlight .vg,
.highlight .vi,
.highlight .vm {
  color: #0550ae;
}
.highlight .o,
.highlight .ow {
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
.highlight .s,
.highlight .sa,
.highlight .sc,
.highlight .dl,
.highlight .sd,
.highlight .s2,
.highlight .se,
.highlight .sh,
.highlight .sx,
.highlight .s1,
.highlight .ss {
  color: #0a3069;
}
.highlight .nd {
  color: #8250df;
}
.highlight .nf,
.highlight .fm {
  color: #8250df;
}
.highlight .err {
  color: #f6f8fa;
  background-color: #82071e;
}
.highlight .c,
.highlight .ch,
.highlight .cd,
.highlight .cm,
.highlight .cp,
.highlight .cpf,
.highlight .c1,
.highlight .cs {
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

.default-theme .theme-header {
  background-color: #f9fafb !important; /* gray-50 */
  color: #374151 !important; /* gray-700 */
  border-bottom: 1px solid #e5e7eb; /* gray-200 */
}

.default-theme .theme-header a {
  color: #374151 !important; /* gray-700 */
}

.default-theme .theme-header a:hover {
  color: #1f2937 !important; /* gray-800 */
}

.default-theme .theme-header button {
  color: #374151 !important; /* gray-700 */
}

.default-theme .theme-header button:hover {
  color: #1f2937 !important; /* gray-800 */
}

.default-theme .theme-footer {
  background-color: #f9fafb !important; /* gray-50 */
  color: #374151 !important; /* gray-700 */
  border-top: 1px solid #e5e7eb !important; /* gray-200 - ヘッダーと同じ境界線 */
}

.default-theme .theme-footer a {
  color: #374151 !important; /* gray-700 */
}

.default-theme .theme-footer a:hover {
  color: #1f2937 !important; /* gray-800 */
}

.slate-theme .blog-title {
  color: #222b45 !important;
}

.slate-theme .theme-header {
  background-color: #222b45 !important;
  color: #e5e7eb !important; /* text-gray-300 相当 */
}

.slate-theme .theme-footer {
  background-color: #222b45 !important;
  color: #e5e7eb !important; /* text-gray-300 相当 */
}

.forest-theme .blog-title {
  color: #1b4332 !important;
}

.forest-theme .theme-header {
  background-color: #1b4332 !important;
  color: #e5e7eb !important; /* text-gray-300 */
}

.forest-theme .theme-footer {
  background-color: #1b4332 !important;
  color: #e5e7eb !important; /* text-gray-300 */
}

.maroon-theme .blog-title {
  color: #3a0a0a !important;
}

.maroon-theme .theme-header {
  background-color: #3a0a0a !important;
  color: #e5e7eb !important; /* text-gray-300 */
}

.maroon-theme .theme-footer {
  background-color: #3a0a0a !important;
  color: #e5e7eb !important; /* text-gray-300 */
}

.midnight-theme .blog-title {
  color: #0a1a2f !important;
}

.midnight-theme .theme-header {
  background-color: #0a1a2f !important;
  color: #e5e7eb !important; /* text-gray-300 相当 */
}

.midnight-theme .theme-footer {
  background-color: #0a1a2f !important;
  color: #e5e7eb !important; /* text-gray-300 相当 */
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

## File: `app/javascript/controllers/auth_modal_controller.js`

```
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["modal", "signinForm", "signupForm", "title"];

  connect() {
    console.log("✅ AuthModal controller connected!");
  }

  showModal() {
    this.modalTarget.classList.remove("hidden");
    this.switchToSignin(); // デフォルトでサインインフォームを表示
  }

  closeModal() {
    this.modalTarget.classList.add("hidden");
  }

  switchToSignin() {
    this.signinFormTarget.classList.remove("hidden");
    this.signupFormTarget.classList.add("hidden");
    this.titleTarget.textContent = "Sign in to your account";
  }

  switchToSignup() {
    this.signinFormTarget.classList.add("hidden");
    this.signupFormTarget.classList.remove("hidden");
    this.titleTarget.textContent = "Create your account";
  }

  closeOnOutsideClick(event) {
    if (event.target === this.modalTarget) {
      this.closeModal();
    }
  }

  stopPropagation(event) {
    event.stopPropagation();
  }

  // ESCキーでも閉じられるようにする
  closeOnEscape(event) {
    if (event.key === "Escape") {
      this.closeModal();
    }
  }
}
```

## File: `app/javascript/controllers/category_modal_controller.js`

```
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["modal", "form", "select"];
  static values = { url: String, locale: String };

  connect() {
    this.boundCloseOnEscape = this.closeOnEscape.bind(this);
    this.boundCloseOnOutsideClick = this.closeOnOutsideClick.bind(this);
  }

  showModal() {
    this.modalTarget.classList.remove("hidden");
    document.addEventListener("keydown", this.boundCloseOnEscape);
    document.addEventListener("click", this.boundCloseOnOutsideClick);
  }

  closeModal() {
    this.modalTarget.classList.add("hidden");
    document.removeEventListener("keydown", this.boundCloseOnEscape);
    document.removeEventListener("click", this.boundCloseOnOutsideClick);
    this.formTarget.reset();
  }

  closeOnEscape(event) {
    if (event.key === "Escape") {
      this.closeModal();
    }
  }

  closeOnOutsideClick(event) {
    if (event.target === this.modalTarget) {
      this.closeModal();
    }
  }

  async submitForm(event) {
    event.preventDefault();

    const formData = new FormData(this.formTarget);
    formData.append("locale", this.localeValue);

    try {
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')
            .content,
        },
        body: formData,
      });

      const data = await response.json();

      if (response.ok) {
        const option = new Option(data.category.name, data.category.id);
        this.selectTarget.add(option);
        this.selectTarget.value = data.category.id;
        this.closeModal();
      } else {
        alert(data.error || "カテゴリの作成に失敗しました");
      }
    } catch (error) {
      console.error("Error:", error);
      alert("エラーが発生した");
    }
  }
}
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
    const url = `/${locale}/images`;

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

## File: `app/javascript/controllers/theme_controller.js`

```
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  changeTheme(event) {
    const color = event.target.value;
    document.documentElement.className = `${color}-theme`;
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

