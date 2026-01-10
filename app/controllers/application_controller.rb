class ApplicationController < ActionController::Base
  include Authorization
  before_action :set_locale
  before_action :set_blog_setting
  before_action :configure_permitted_parameters, if: :devise_controller?

  # skip_before_action :verify_authenticity_token

  # protect_from_forgery with: :exception

  # Devise関連のみCSRF検証をスキップ
  skip_before_action :verify_authenticity_token, if: :devise_controller?
  protect_from_forgery with: :exception, unless: :devise_controller?


  def set_locale
    I18n.locale = params[:locale] || I18n.default_locale
  end

  def default_url_options
    # より安全な書き方
    locale = params[:locale] || I18n.locale || "ja"
    { locale: locale }
  end

  def set_blog_setting
    if params[:username].present?
      user = User.find_by(username: params[:username])
      @blog_setting = user&.blog_setting
    elsif user_signed_in?
      @blog_setting = current_user.blog_setting
    end
  end

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :username ])
    devise_parameter_sanitizer.permit(:account_update, keys: [ :username ])
  end
end
