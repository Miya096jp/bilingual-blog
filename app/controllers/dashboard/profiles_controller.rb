class Dashboard::ProfilesController < ApplicationController
  include UploadedFilesOnly

  before_action :authenticate_user!
  layout "dashboard"

  def show
    @user = current_user
  end

  def edit
    @user = current_user
  end

  def update
    @user = current_user
    if @user.update(profile_params)
      redirect_to edit_dashboard_profile_path, notice: "プロフィールを更新しました"
    else
      render :edit
    end
  end

  private

  def profile_params
    permitted = params.require(:user).permit(:nickname_ja, :nickname_en, :profile_body_ja, :profile_body_en, :avatar, :portrait)
    uploaded_files_only(permitted, :avatar, :portrait)
  end
end
