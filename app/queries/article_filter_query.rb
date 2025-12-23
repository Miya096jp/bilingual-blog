class ArticleFilterQuery
  attr_reader :user, :locale, :category_id, :tag_id

  def initialize(params = {})
    @locale = params[:locale]
    @category_id = params[:category_id]
    @tag_id = params[:tag_id]
    @user = params[:user]
  end

  def call
    articles_scope.for_listing(locale)
      .by_category(category_id)
      .by_tags(tag_id, user)
  end

  # 修正？
  def current_category
    @current_category ||= Category.find_by(id: category_id) if category_id.present?
  end

  def current_tags
    @current_tags ||= user&.tags&.where(id: tag_id) if tag_id.present? && user.present?
  end

  def filter_params
    {
      locale: locale,
      category_id: category_id,
      tag_id: tag_id
    }.compact
  end

  private

  def articles_scope
    user&.articles || Article.none
  end
end
