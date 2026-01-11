class Users::SessionsController < Devise::SessionsController
  respond_to :html, :turbo_stream

  def create
    self.resource = warden.authenticate(auth_options)
    if resource
      set_flash_message!(:notice, :signed_in)
      sign_in(resource_name, resource)
      yield resource if block_given?
      
      redirect_to after_sign_in_path_for(resource), status: :see_other
    else
      self.resource = resource_class.new(sign_in_params)
      clean_up_passwords(resource)

      flash.now[:alert] = "メールアドレスまたはパスワードが違います。"

      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }

        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "auth_form_frame",
            template: "devise/sessions/new",
            locals: { resource: resource, resource_name: resource_name }
          )
        end
      end
    end
  end
end
