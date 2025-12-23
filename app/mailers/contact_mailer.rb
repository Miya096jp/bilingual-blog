class ContactMailer < ApplicationMailer
  default from: "noreply@dualpascal.com"
  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   en.contact_mailer.new_contact.subject
  #
  def new_contact(contact)
    @contact = contact
    mail(
      to: "miyawaki.yske@gmail.com",
      subject: "[問い合わせ] #{@contact.subject}"
    )
  end
end
