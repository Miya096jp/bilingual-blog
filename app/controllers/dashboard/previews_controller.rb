class Dashboard::PreviewsController < ApplicationController
  include MarkdownRenderable

  before_action :authenticate_user!
  layout "dashboard"

  def create
    render json: { html: render_markdown(params[:content]) }
  rescue => e
    Rails.logger.error "Preview error: #{e.message}"
    render json: { error: "プレビュー生成でエラーが発生しました" }, status: 422
  end
end
