class Dashboard::ImagesController < ApplicationController
  before_action :authenticate_user!
  layout "dashboard"

  def create
    # 直接Active Storage::Blobとして保存
    blob = ActiveStorage::Blob.create_and_upload!(
      io: params[:image],
      filename: params[:image].original_filename,
      content_type: params[:image].content_type
    )

    variant = blob.variant(resize_to_limit: [ 800, 600 ]).processed
    image_url = url_for(variant)
    # image_url = url_for(blob)
    render json: { url: image_url }
  rescue => e
    render json: { error: "画像のアップロードに失敗しました: #{e.message}" }, status: 422
  end
end
