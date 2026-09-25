class Dashboard::AttachmentsController < ApplicationController
  before_action :authenticate_user!

  def destroy
    attachment = ActiveStorage::Attachment.find(params[:id])
    record = attachment.record
    raise ActiveRecord::RecordNotFound unless owner?(record)

    attachment.purge

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "cover_image_section",
          partial: "dashboard/articles/cover_image_field",
          locals: { record: record }
        )
      end

      format.html { redirect_back fallback_location: root_path, notice: "画像を削除しました" }
    end
  end

  private

  def owner?(record)
    case record
    when User
      record == current_user
    when Article
      record.user_id == current_user.id
    else
      false
    end
  end
end
