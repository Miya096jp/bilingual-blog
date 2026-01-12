class Users::PasswordsController < Devise::PasswordsController
  protected

  # パスワードリセット送信後のリダイレクト先を変更
  def after_sending_reset_password_instructions_path_for(resource_name)
    root_path
  end
end
