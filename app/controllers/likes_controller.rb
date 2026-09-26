class LikesController < ApplicationController
  before_action :set_article

  def create
    @like = @article.likes.build(new_like_attributes)

    if @like.save
      respond_to do |format|
        format.html { redirect_back(fallback_location: user_article_path(@article.user.username, @article, locale: params[:locale])) }
        format.turbo_stream { render turbo_stream: turbo_stream.replace("like_button_#{@article.id}", partial: "shared/like_button", locals: { article: @article }) }
      end
    else
      redirect_back(fallback_location: user_article_path(@article.user.username, @article, locale: params[:locale]), alert: "いいねできませんでした")
    end
  end

  def destroy
    @like = find_current_like
    @like&.destroy

    respond_to do |format|
      format.html { redirect_back(fallback_location: user_article_path(@article.user.username, @article, locale: params[:locale])) }
      format.turbo_stream { render turbo_stream: turbo_stream.replace("like_button_#{@article.id}", partial: "shared/like_button", locals: { article: @article }) }
    end
  end

  private

  def set_article
    @article = Article.published.where(user: User.not_suspended).find(params[:article_id])
  end

  def new_like_attributes
    user_signed_in? ? { user: current_user } : { visitor_token: ensure_visitor_token }
  end

  def find_current_like
    if user_signed_in?
      @article.likes.find_by(user: current_user)
    elsif visitor_token.present?
      @article.likes.find_by(visitor_token: visitor_token)
    end
  end
end
