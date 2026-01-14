# frozen_string_literal: true

class Users::ConfirmationsController < Devise::ConfirmationsController
  # GET /resource/confirmation?confirmation_token=abcdef
  def show
    self.resource = resource_class.confirm_by_token(params[:confirmation_token])
    yield resource if block_given?

    if resource.errors.empty?
      # 確認成功
      set_flash_message!(:notice, :confirmed)
      sign_in(resource_name, resource)
      
      # ビューを表示せず、直接リダイレクト
      redirect_to after_confirmation_path_for(resource_name, resource)
    else
      # 確認失敗（トークンが無効など）
      respond_with_navigational(resource.errors, status: :unprocessable_entity) { render :new }
    end
  end

  protected

  # 確認後のリダイレクト先
  def after_confirmation_path_for(resource_name, resource)
    dashboard_articles_path(locale: I18n.locale)
  end
end
