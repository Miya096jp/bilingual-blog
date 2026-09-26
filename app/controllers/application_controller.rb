class ApplicationController < ActionController::Base
  include Authorization
  before_action :set_locale
  before_action :set_blog_setting
  before_action :configure_permitted_parameters, if: :devise_controller?

  protect_from_forgery with: :exception, prepend: true
  rescue_from ActionController::InvalidAuthenticityToken, with: :handle_invalid_authenticity_token

  def set_locale
    if request.path.start_with?("/dashboard") || request.path.start_with?("/admin")
      I18n.locale = I18n.default_locale
    else
      I18n.locale = params[:locale] || I18n.default_locale
    end
  end

  # def default_url_options
  #   if request.path.start_with?('/dashboard') || request.path.start_with?('/admin')
  #     {}
  #   else
  #     { locale: params[:locale] || I18n.locale || "ja" }
  #   end
  # end

  def default_url_options
    if request.path.start_with?("/users") ||
      request.path.start_with?("/dashboard") ||
      request.path.start_with?("/admin")
      {}
    else
      { locale: params[:locale] || I18n.locale || "ja" }
    end
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

  private

  # ログイン画面を開いたまま時間が経つなどしてトークンが古くなった場合に、
  # 汎用の422ページではなく、理由が分かる形でトップへ戻す
  def handle_invalid_authenticity_token(exception)
    raise exception unless devise_controller?

    redirect_to root_path(locale: I18n.locale), alert: "ページの有効期限が切れました。もう一度お試しください。", status: :see_other
  end

  def visitor_token
    cookies.signed[:visitor_token]
  end
  helper_method :visitor_token

  def ensure_visitor_token
    visitor_token || begin
      token = SecureRandom.uuid
      cookies.permanent.signed[:visitor_token] = {
        value: token,
        httponly: true,
        same_site: :lax
      }
      token
    end
  end
end
