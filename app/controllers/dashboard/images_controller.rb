class Dashboard::ImagesController < ApplicationController
  before_action :authenticate_user!
  layout "dashboard"

  # Article#images / User#avatar,portrait の active_storage_validations と揃えている。
  # このコントローラはモデルの添付を経由せず blob を直接作るため、モデル側のバリデーションが効かない。
  ALLOWED_CONTENT_TYPES = %w[image/png image/jpeg image/webp].freeze
  MAX_SIZE = 5.megabytes

  def create
    file = params[:image]
    return render_error("画像を選択してください") if file.blank?
    return render_error("ファイルサイズは5MB未満にしてください") if file.size >= MAX_SIZE

    detected_content_type = Marcel::MimeType.for(file)
    unless detected_content_type == file.content_type && ALLOWED_CONTENT_TYPES.include?(detected_content_type)
      return render_error("対応していない画像形式です")
    end

    blob = ActiveStorage::Blob.create_and_upload!(
      io: file,
      filename: file.original_filename,
      content_type: detected_content_type
    )

    variant = blob.variant(resize_to_limit: [ 800, 600 ]).processed
    image_url = url_for(variant)
    render json: { url: image_url }
  rescue => e
    render_error("画像のアップロードに失敗しました: #{e.message}")
  end

  private

  def render_error(message)
    render json: { error: message }, status: :unprocessable_entity
  end
end
