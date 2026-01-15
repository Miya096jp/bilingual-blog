class Users::RegistrationsController < Devise::RegistrationsController
  layout "dashboard", only: [:delete_confirmation]
  respond_to :html, :turbo_stream

  def new
    if turbo_frame_request?
      build_resource
      render layout: false
    else
      redirect_to root_path(locale: I18n.locale), alert: "このページは利用できません"
    end
  end

  def edit
    if turbo_frame_request?
      super
    else
      redirect_to edit_dashboard_profile_path(locale: I18n.locale), alert: "ダッシュボードから編集してください"
    end
  end

  def delete_confirmation
    @resource = current_user
  end

  def create
    build_resource(sign_up_params)

    resource.save
    yield resource if block_given?
    if resource.persisted?
      if resource.active_for_authentication?
        set_flash_message! :notice, :signed_up
        sign_in(resource_name, resource)
        respond_with resource, location: after_sign_up_path_for(resource)
      else
        set_flash_message! :notice, :"signed_up_but_#{resource.inactive_message}"
        expire_data_after_sign_in!
        respond_with resource, location: after_inactive_sign_up_path_for(resource)
      end
    else
      clean_up_passwords resource
      set_minimum_password_length

      flash.now[:alert] = resource.errors.full_messages.join("\n")

      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }

        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "auth_form_frame",
            template: "devise/registrations/new",
            locals: { resource: resource, resource_name: resource_name }
          )
        end
      end
    end
  end

  protected

  def after_sign_out_path_for(resource_or_scope)
    root_path(locale: I18n.locale)
  end
end
