class Dashboard::ExportsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_article

  def show
    # ファイル名を生成（日本語文字の処理）
    safe_title = sanitize_filename(@article.title)
    filename = "#{safe_title}_#{@article.locale}.md"

    # Markdownコンテンツを生成
    markdown_content = generate_markdown_content(@article)

    # ファイルとしてダウンロード
    send_data markdown_content,
              filename: filename,
              type: "text/markdown",
              disposition: "attachment"
  end

  private

  def set_article
    @article = current_user.articles.find(params[:article_id])
  end


  def sanitize_filename(title)
    # 日本語（Unicode文字）と英数字、ハイフン、アンダースコア以外を削除
    title.gsub(/[^\p{L}\p{N}\s-]/u, "").gsub(/\s+/, "_").strip
  end

  def generate_markdown_content(article)
    content = []

    # メタデータ部分
    content << "# #{article.title}"
    content << ""
    content << "**カテゴリ**: #{article.category&.name || '未設定'}"
    content << "**タグ**: #{article.tags.pluck(:name).join(', ')}" if article.tags.any?
    content << "**投稿日**: #{article.published_at&.strftime('%Y年%m月%d日') || article.created_at.strftime('%Y年%m月%d日')}"
    content << ""
    content << "---"
    content << ""

    # 記事本文
    content << article.content

    content.join("\n")
  end
end
