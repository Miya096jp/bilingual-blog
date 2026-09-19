module DashboardHelper
  def dashboard_nav_active?(*controller_paths)
    controller_paths.include?(controller.controller_path)
  end

  def dashboard_status_badge(article)
    if article.published?
      content_tag :span, "公開", class: "inline-block px-2 py-0.5 rounded-full text-xs font-medium bg-[#E7F2EC] text-[#14634A]"
    else
      content_tag :span, "下書き", class: "inline-block px-2 py-0.5 rounded-full text-xs font-medium bg-[#FBF0DC] text-[#7A5314]"
    end
  end

  # article: 表示対象の記事(原文または翻訳)。original: そのペアの原文記事。
  def dashboard_article_edit_path_for(article, original)
    article.original? ? edit_dashboard_article_path(article) : edit_dashboard_article_translation_path(original)
  end

  # counts: current_user.articles.group(:locale, :status).count の結果
  def dashboard_locale_summary(counts, locale)
    published = counts[[ locale, "published" ]] || 0
    draft = counts[[ locale, "draft" ]] || 0
    "#{published + draft} 件(公開 #{published}・下書き #{draft})"
  end
end
