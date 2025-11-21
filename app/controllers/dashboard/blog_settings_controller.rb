class Dashboard::BlogSettingsController < ApplicationController
  before_action :authenticate_user!
  layout "dashboard"

  def edit
    @blog_setting = current_user.blog_setting
  end

  def update
    @blog_setting = current_user.blog_setting

    if @blog_setting.update(blog_setting_params)
      redirect_to edit_dashboard_blog_setting_path, notice: "ブログ設定を更新しました"
    else
      render :edit
    end
  end

  private

  def blog_setting_params
    params.require(:blog_setting).permit(:blog_title_ja, :blog_title_en, :blog_subtitle_ja, :blog_subtitle_en, :theme_color, :header_image)
  end
end
