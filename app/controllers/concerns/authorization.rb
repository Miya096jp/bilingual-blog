module Authorization
  extend ActiveSupport::Concern

  private

  def require_admin
    redirect_to root_path, alert: "アクセス権限がありません" unless current_user&.admin?
  end
end
