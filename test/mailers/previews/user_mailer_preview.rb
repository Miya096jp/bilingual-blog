# Preview all emails at http://localhost:3000/rails/mailers/user_mailer
class UserMailerPreview < ActionMailer::Preview
  def confirmation_instructions
    UserMailer.confirmation_instructions(user, "preview-token")
  end

  def reset_password_instructions
    UserMailer.reset_password_instructions(user, "preview-token")
  end

  def email_changed
    user.unconfirmed_email = "new@example.com"
    UserMailer.email_changed(user)
  end

  def password_change
    UserMailer.password_change(user)
  end

  private

  def user
    @user ||= User.first
  end
end
