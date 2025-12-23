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
