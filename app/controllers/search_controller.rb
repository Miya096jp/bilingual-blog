class SearchController < ApplicationController
  def index
    @search_keyword = params[:q]
    Rails.logger.info "Search keyword: #{@search_keyword}"
    @articles = if @search_keyword.present?
                  user = User.find_by(username: params[:username])
                  user.articles.published
                    .where(locale: params[:locale])
                    .search(@search_keyword)
                    .includes(:category, :tags)
                    .order(published_at: :desc)
                    .page(params[:page]).per(10)
    else
                  current_user.articles.none.page(1)
    end
    @filter = ArticleFilterQuery.new(params.merge(user: user))
  end
end
