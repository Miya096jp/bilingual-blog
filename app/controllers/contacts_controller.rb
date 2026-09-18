class ContactsController < ApplicationController
  def new
    @contact = Contact.new
  end

  def create
    if honeypot_filled?
      redirect_to new_contact_path, notice: "お問い合わせを送信しました。ありがとうございます。"
      return
    end

    @contact = Contact.new(contact_params)

    if @contact.save
      ContactMailer.new_contact(@contact).deliver_now
      redirect_to new_contact_path, notice: "お問い合わせを送信しました。ありがとうございます。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  # ハニーポット欄に値が入っていたらボットとみなす。保存・メール送信は行わないが、
  # 通常送信時と同じ表示にしてボットに気づかせない。
  def honeypot_filled?
    params.dig(:contact, :website).present?
  end

  def contact_params
    params.require(:contact).permit(:name, :email, :subject, :message)
  end
end
