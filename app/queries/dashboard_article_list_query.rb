class DashboardArticleListQuery
  STATUS_OPTIONS = {
    "" => "すべて",
    "draft" => "下書き",
    "published" => "公開",
    "no_translation" => "翻訳なし"
  }.freeze

  SORT_OPTIONS = {
    "updated_desc" => "更新が新しい順",
    "created_asc" => "作成が古い順"
  }.freeze

  TRANSLATION_JOIN = <<~SQL.squish
    LEFT JOIN articles AS translations ON translations.original_article_id = articles.id
  SQL

  attr_reader :user, :keyword, :status, :sort

  def initialize(user:, params: {})
    @user = user
    @keyword = params[:q].presence
    @status = STATUS_OPTIONS.key?(params[:status].to_s) ? params[:status].presence : nil
    @sort = SORT_OPTIONS.key?(params[:sort]) ? params[:sort] : "updated_desc"
  end

  def call
    scope = base_scope
    scope = apply_search(scope)
    scope = apply_status_filter(scope)
    apply_sort(scope)
  end

  def filtering?
    keyword.present? || status.present?
  end

  def filter_params
    { q: keyword, status: status, sort: sort }.compact_blank
  end

  private

  def base_scope
    user.articles
        .where(original_article_id: nil)
        .joins(TRANSLATION_JOIN)
        .includes(:translation, :category, :tags)
  end

  def apply_search(scope)
    return scope if keyword.blank?

    like = "%#{ActiveRecord::Base.sanitize_sql_like(keyword)}%"
    original_ids = user.articles
                        .where("title ILIKE ?", like)
                        .pluck(:id, :original_article_id)
                        .map { |id, original_id| original_id || id }
                        .uniq

    scope.where(id: original_ids)
  end

  def apply_status_filter(scope)
    case status
    when "draft"
      scope.where(
        "articles.status = :draft OR translations.status = :draft",
        draft: Article.statuses["draft"]
      )
    when "published"
      scope.where(
        "articles.status = :published AND translations.status = :published",
        published: Article.statuses["published"]
      )
    when "no_translation"
      scope.where("translations.id IS NULL")
    else
      scope
    end
  end

  def apply_sort(scope)
    case sort
    when "created_asc"
      scope.order(created_at: :asc, id: :asc)
    else
      scope.order(Arel.sql("GREATEST(articles.updated_at, translations.updated_at) DESC"), id: :desc)
    end
  end
end
