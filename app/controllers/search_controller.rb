class SearchController < ApplicationController
  before_action :set_blog_owner

  def index
    @query = params[:q]
    if @query.present?
      @articles = @blog_owner.articles
                             .published
                             .by_locale(params[:locale])
                             .search(@query)
                             .page(params[:page]).per(10)
    else
      @articles = Article.none.page(1)
    end
  end

  private

  def set_blog_owner
    @blog_owner = User.find_by!(username: params[:username])
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path(locale: params[:locale]), alert: "ユーザーが見つかりません"
  end
end
