class ApplicationController < ActionController::Base
  include Authorization
  around_action :switch_locale
  before_action :set_blog_setting
  before_action :configure_permitted_parameters, if: :devise_controller?

  protect_from_forgery with: :exception, prepend: true
  rescue_from ActionController::InvalidAuthenticityToken, with: :handle_invalid_authenticity_token

  # I18n.locale はスレッドローカルで、Railsはリクエストごとにリセットしないため、
  # with_locale でリクエストが終わったら元に戻し、次のリクエストに持ち越さない
  def switch_locale(&action)
    locale =
      if request.path.start_with?("/dashboard") || request.path.start_with?("/admin")
        I18n.default_locale
      else
        params[:locale] || I18n.default_locale
      end
    I18n.with_locale(locale, &action)
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

    redirect_to welcome_path(locale: locale_for_invalid_authenticity_token), alert: "ページの有効期限が切れました。もう一度お試しください。", status: :see_other
  end

  # CSRFの検証は switch_locale より先に走るため、I18n.locale ではなくリクエストからロケールを決める。
  # ログインフォームは /users/... へPOSTされ params[:locale] を持たないので、
  # フォームを開いたページ（同じホストのReferer）のロケールを使う
  def locale_for_invalid_authenticity_token
    candidates = [ params[:locale], locale_from_referer ]
    candidates.find { |locale| I18n.available_locales.map(&:to_s).include?(locale) } || I18n.default_locale
  end

  def locale_from_referer
    uri = URI.parse(request.referer.to_s)
    return unless uri.host == request.host

    uri.path.to_s[%r{\A/([^/]+)}, 1]
  rescue URI::InvalidURIError
    nil
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
