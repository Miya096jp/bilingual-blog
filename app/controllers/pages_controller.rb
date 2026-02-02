class PagesController < ApplicationController
  skip_before_action :require_login, only: %i[about], raise: false

  def about
  end
end
