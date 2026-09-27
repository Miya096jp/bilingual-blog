module MarkdownRenderable
  extend ActiveSupport::Concern

  include ActionView::Helpers::SanitizeHelper

  # sanitize の既定の許可リストに加えて、class 属性のクラスを1つずつ判定し、
  # Rouge と kramdown が出すものだけを残す。本文に書いたクラスでビルド済みの
  # Tailwind のクラスが効き、本文の枠を越えて画面を覆えてしまうのを防ぐため。
  class ContentScrubber < Rails::HTML::PermitScrubber
    ALLOWED_CLASSES = (
      %w[highlighter-rouge highlight] +
      %w[task-list task-list-item task-list-item-checkbox footnote footnotes reversefootnote] +
      Rouge::Token.cache.values.map(&:shortname).reject(&:empty?)
    ).to_set.freeze
    ALLOWED_CLASS_PATTERN = /\Alanguage-[\w+#-]+\z/

    def initialize
      super
      sanitizer = ActionView::Helpers::SanitizeHelper.sanitizer_vendor.safe_list_sanitizer
      self.tags = sanitizer.allowed_tags
      self.attributes = sanitizer.allowed_attributes
    end

    private

    def scrub_attributes(node)
      super

      return unless node["class"]

      classes = node["class"].split.select { |name| allowed_class?(name) }
      if classes.empty?
        node.remove_attribute("class")
      else
        node["class"] = classes.join(" ")
      end
    end

    def allowed_class?(name)
      ALLOWED_CLASSES.include?(name) || ALLOWED_CLASS_PATTERN.match?(name)
    end
  end

  private

  def render_markdown(source)
    html = Kramdown::Document.new(source.to_s,
      input: "GFM",
      syntax_highlighter: "rouge"
    ).to_html
    sanitize(html, scrubber: ContentScrubber.new).html_safe
  end
end
