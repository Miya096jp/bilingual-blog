class Dashboard::AccountController < ApplicationController
  before_action :authenticate_user!
  layout "dashboard"

  def delete_confirmation
    @user = current_user
  end
end
