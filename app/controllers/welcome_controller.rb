class WelcomeController < ApplicationController
  layout "welcome"

  def index
    @operator = User.admin.order(:id).first
    @articles = @operator&.articles&.for_listing(I18n.locale)&.limit(3) || Article.none
  end
end
