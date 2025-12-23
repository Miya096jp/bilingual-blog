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
