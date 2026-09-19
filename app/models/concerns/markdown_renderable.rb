module MarkdownRenderable
  extend ActiveSupport::Concern

  include ActionView::Helpers::SanitizeHelper

  private

  def render_markdown(source)
    html = Kramdown::Document.new(source.to_s,
      input: "GFM",
      syntax_highlighter: "rouge"
    ).to_html
    sanitize(html).html_safe
  end
end
