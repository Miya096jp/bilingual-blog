class Dashboard::PreviewsController < ApplicationController
  before_action :authenticate_user!
  layout "dashboard"

  def create
    content = params[:content]

    # content = content.strip.gsub(/^[ \t]+/, "")

    html = Kramdown::Document.new(content,
      input: "GFM",
      syntax_highlighter: "rouge"
    ).to_html

    render json: { html: html }
  rescue => e
    Rails.logger.error "Preview error: #{e.message}"
    render json: { error: "プレビュー生成でエラーが発生しました: #{e.message}" }, status: 422
  end
end
