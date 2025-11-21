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
