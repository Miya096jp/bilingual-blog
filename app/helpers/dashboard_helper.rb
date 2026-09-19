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

  # 絞り込みチップのリンク用に、現在のq/sortを保ったままstatusだけ書き換えたparamsを返す
  def dashboard_filter_link_params(status:)
    params.permit(:q, :sort).to_h.symbolize_keys.merge(status: status).compact_blank
  end

  # ダッシュボード各画面のh1。記事一覧の見出しを基準に、サイズ・太さ・色を揃える。
  # 下余白はラッパーを持つ画面ではラッパー側が持つため、必要な画面だけ class: "mb-6" を渡す。
  # danger: true は危険な操作の画面(アカウント削除など)向けに色を赤にする。
  def dashboard_page_title(title, danger: false, **options)
    color = danger ? "text-red-600" : "text-[#1B1B19]"
    options[:class] = [ "text-2xl font-bold", color, options[:class] ].compact.join(" ")
    content_tag :h1, title, **options
  end
end
