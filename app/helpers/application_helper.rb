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
end
