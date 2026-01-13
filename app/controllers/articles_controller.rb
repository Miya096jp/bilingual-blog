class ArticlesController < ApplicationController
  # before_action :set_user
  before_action :set_blog_owner
  before_action :set_blog_setting
  before_action :set_locale

  def index
    # @filter = ArticleFilterQuery.new(params.merge(user: @user))
    @filter = ArticleFilterQuery.new(params.merge(user: @blog_owner))
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

  def set_blog_owner
    @blog_owner = User.find_by!(username: params[:username])
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path(locale: params[:locale]), alert: "ユーザーが見つかりません"
  end

  # def set_user
  #   @user = User.find_by!(username: params[:username])
  # end

  def set_locale
    I18n.locale = params[:locale] || I18n.default_locale
  end

  def set_blog_setting
    @blog_setting = @blog_owner.blog_setting || @blog_owner.build_blog_setting
  end
end
