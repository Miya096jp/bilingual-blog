class Admin::ContactsController < Admin::BaseController
  def index
    @contacts = Contact.order(created_at: :desc)
                      .page(params[:page])
                      .per(20)
  end

  def show
    @contact = Contact.find(params[:id])
  end

  def update
    @contact = Contact.find(params[:id])

    if @contact.update(contact_params)
      status = @contact.resolved? ? "対応済み" : "未対応"
      redirect_to admin_contacts_path, notice: "お問い合わせを#{status}にしました"
    else
      redirect_to admin_contacts_path, alert: "操作に失敗しました"
    end
  end

  private

  def contact_params
    params.require(:contact).permit(:resolved)
  end
end
