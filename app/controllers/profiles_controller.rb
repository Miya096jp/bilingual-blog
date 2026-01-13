class ProfilesController < ApplicationController
  before_action :set_blog_owner

  def show
    # @user = User.find_by!(username: params[:username])
    @user = @blog_owner
    @current_locale = params[:locale] || I18n.locale
  end

  private

  def set_blog_owner
    @blog_owner = User.find_by!(username: params[:username])
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path(locale: params[:locale]), alert: "ユーザーが見つかりません"
  end
end
