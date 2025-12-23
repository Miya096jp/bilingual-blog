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
