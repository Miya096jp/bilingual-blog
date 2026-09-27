class UserMailer < Devise::Mailer
  layout "user_mailer"

  # 利用者のロケールに関わらず、メールは日本語に固定する
  around_action { |_mailer, action| I18n.with_locale(:ja, &action) }
end
