class CommentsController < ApplicationController
  before_action :set_blog_owner
  before_action :set_article

  def create
    @comment = @article.comments.build(comment_params)

    if @comment.save
      redirect_to user_article_path(username: @blog_owner.username, id: @article, locale: params[:locale]), 
                  notice: "コメントを投稿しました"
    else
      redirect_to user_article_path(username: @blog_owner.username, id: @article, locale: params[:locale]), 
                  alert: "コメントの投稿に失敗しました"
    end
  end

  private

  def set_blog_owner
    @blog_owner = User.find_by!(username: params[:username])
  end

  def set_article
    @article = @blog_owner.articles.published.find(params[:article_id])
  end

  def comment_params
    params.require(:comment).permit(:author_name, :content, :website)
  end
end
