class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def github
    handle_omniauth("github")
  end

  def google_oauth2
    handle_omniauth("google_oauth2")
  end

  def handle_omniauth(provider)
    result = User.from_omniauth(request.env["omniauth.auth"])
    @user = result[:user]

    if @user.persisted?
      # 重要: sign_in_and_redirectでセッションを確実に作成
      sign_in_and_redirect @user, event: :authentication
      if result[:is_new]
        flash[:notice] = "アカウントを作成しました"
      elsif result[:password_reset]
        flash[:notice] = "既存アカウントでログインしました。登録時のパスワードは無効になったため、パスワードでログインする場合は再設定してください"
      else
        flash[:notice] = "既存アカウントでログインしました"
      end
    else
      session["devise.#{provider}_data"] = request.env["omniauth.auth"].except("extra")
      redirect_to new_user_registration_url
    end
  end


  # def handle_omniauth(provider)
  #   result = User.from_omniauth(request.env["omniauth.auth"])
  #   @user = result[:user]
  #
  #   if @user.persisted?
  #     if result[:is_new]
  #       flash[:notice] = "アカウントを作成しました"
  #     else
  #       flash[:notice] = "既存アカウントでログインしました"
  #     end
  #     redirect_to dashboard_articles_path
  #   else
  #     rediret_to dashboard_articles_path
  #     session["devise.#{provider}_data"] = request.env["omniauth.auth"].except("extra")
  #       redirect_to new_user_registration_url
  #   end
  # end

  def failure
    redirect_to root_path
  end
end
