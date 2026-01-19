class LikesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_article

  def create
    @like = @article.likes.build(user: current_user)

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
    @like = @article.likes.find_by(user: current_user)
    @like&.destroy

    respond_to do |format|
      format.html { redirect_back(fallback_location: user_article_path(@article.user.username, @article, locale: params[:locale])) }
      format.turbo_stream { render turbo_stream: turbo_stream.replace("like_button_#{@article.id}", partial: "shared/like_button", locals: { article: @article }) }
    end
  end

  private

  def set_article
    @article = Article.find(params[:article_id])
  end
end
