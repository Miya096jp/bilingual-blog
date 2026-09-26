class CommentsController < ApplicationController
  def create
    @article = Article.published.where(user: User.not_suspended).find(params[:article_id])

    if honeypot_filled?
      redirect_to user_article_path(@article.user.username, @article.id, locale: params[:locale]), notice: comment_created_message
      return
    end

    @comment = @article.comments.build(comment_params)

    if @comment.save
      redirect_to user_article_path(@article.user.username, @article.id, locale: params[:locale]), notice: comment_created_message
    else
      redirect_to user_article_path(@article.user.username, @article.id, locale: params[:locale]), alert: @comment.errors.full_messages.join("、")
    end
  end

  private

  # ハニーポット欄に値が入っていたらボットとみなす。保存は行わないが、
  # 通常投稿時と同じ表示にしてボットに気づかせない。
  # 本物の website 欄（投稿者の URL）があるため、お問い合わせフォームとは別の名前にしている。
  def honeypot_filled?
    params.dig(:comment, :homepage).present?
  end

  def comment_params
    params.require(:comment).permit(:author_name, :website, :content)
  end

  def comment_created_message
    params[:locale] == "ja" ? "コメントを投稿しました" : "Comment posted"
  end
end
