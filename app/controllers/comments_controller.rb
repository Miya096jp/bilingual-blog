class CommentsController < ApplicationController
  def create
    @article = Article.find(params[:article_id])
    @comment = @article.comments.build(comment_params)

    if @comment.save
      redirect_to user_article_path(@article.user.username, @article.id, locale: params[:locale]), notice: comment_created_message
    else
      redirect_to user_article_path(@article.user.username, @article.id, locale: params[:locale]), alert: @comment.errors.full_messages.join("、")
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path(locale: params[:locale]), alert: article_not_found_message
  end

  private

  def comment_params
    params.require(:comment).permit(:author_name, :website, :content)
  end

  def comment_created_message
    params[:locale] == "ja" ? "コメントを投稿しました" : "Comment posted"
  end

  def article_not_found_message
    params[:locale] == "ja" ? "記事が見つかりません" : "Article not found"
  end
end
