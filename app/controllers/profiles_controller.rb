class ProfilesController < ApplicationController
  def show
    @user = User.find_by!(username: params[:username])
    @current_locale = params[:locale] || I18n.locale
  end
end
