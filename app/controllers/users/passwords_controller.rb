class Users::PasswordsController < Devise::PasswordsController
  def new
    if turbo_frame_request?
      self.resource = resource_class.new
      render layout: false
    else
      redirect_to root_path(locale: I18n.locale), alert: "このページは利用できません"
    end
  end

  protected

  # パスワードリセット送信後のリダイレクト先を変更
  def after_sending_reset_password_instructions_path_for(resource_name)
    root_path
  end
end
