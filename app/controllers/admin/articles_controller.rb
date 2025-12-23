# app/controllers/admin/articles_controller.rb
class Admin::ArticlesController < Admin::BaseController
  def index
    @articles = Article.includes(:user, :category)
                      .order(created_at: :desc)
                      .page(params[:page])
                      .per(20)
  end

  def destroy
    @article = Article.find(params[:id])
    if @article.destroy
      redirect_to admin_articles_path, notice: "記事「#{@article.title}」を削除しました"
    else
      redirect_to admin_articles_path, alert: "削除に失敗しました"
    end
  end
end
