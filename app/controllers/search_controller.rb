class SearchController < ApplicationController
  def index
    @search_keyword = params[:q]
    @articles = if @search_keyword.present?
                  Article.published
                    .where(locale: params[:locale])
                    .search(@search_keyword)
                    .includes(:category, :tags)
                    .order(published_at: :desc)
                    .page(params[:page]).per(10)
    else
                  Article.none.page(1)
    end
  end
end
