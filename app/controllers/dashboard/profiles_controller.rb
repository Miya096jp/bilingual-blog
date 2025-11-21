class Dashboard::ProfilesController < ApplicationController
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
    params.require(:user).permit(:nickname_ja, :nickname_en, :bio_ja, :bio_en, :website, :location_ja, :location_en, :twitter_handle, :facebook_handle, :linkedin_handle, :github_handle, :qiita_handle, :zenn_handle, :hatena_handle, :avatar)
  end
end
