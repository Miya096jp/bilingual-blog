class ApplicationController < ActionController::Base
  include Authorization
  before_action :set_locale
  before_action :set_blog_setting

  protect_from_forgery with: :exception

  def set_locale
    I18n.locale = params[:locale] || I18n.default_locale
  end

  def default_url_options
    # より安全な書き方
    locale = params[:locale] || I18n.locale || "ja"
    { locale: locale }
  end

  # def set_blog_setting
  #   if params[:username].present?
  #     user = User.find_by(username: params[:username])
  #     @blog_setting = user&.blog_setting
  #   end
  # end

  def set_blog_setting
    if params[:username].present?
      user = User.find_by(username: params[:username])
      @blog_setting = user&.blog_setting
    elsif user_signed_in?
      @blog_setting = current_user.blog_setting
    end
  end
end
