module ApplicationHelper
  def thumbnail_for_article(article, blog_setting)
    if article.cover_image.attached?
      article.cover_image.variant(resize_to_limit: [ 400, 300 ])
    else
      nil
    end
  end

  def has_cover_image?(article)
    article.cover_image.attached?
  end

  def default_meta_tags
    {
      site: "Dual Pascal",
      title: "日英バイリンガルブログプラットフォーム",
      reverse: true,
      separator: "|",
      description: "Dual Pascalは、世界に情報発信したいエンジニアのためのブログプラットフォームです。",
      keywords: "エンジニア, 技術ブログ, プログラミング, 英語, 情報発信",
      canonical: request.original_url,
      noindex: !Rails.env.production?,
      icon: [
        { href: image_url("dualpascal_icon.png") },
        { href: image_url("dualpascal_icon.png"), rel: "apple-touch-icon", sizes: "180x180", type: "image/png" }
      ],
      og: {
        site_name: "Dual Pascal",
        title: :title,
        description: :description,
        type: "website",
        url: request.original_url,
        image: image_url("dualpascal_official_image.png"),
        locale: "ja_JP"
      },
      twitter: {
        card: "summary_large_image"
      }
    }
  end
end
