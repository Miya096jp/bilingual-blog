class AddForeignKeyAndIndexToArticles < ActiveRecord::Migration[8.0]
  def change
    add_foreign_key :articles, :articles, column: :original_article_id, on_delete: :cascade
    add_index :articles, :published_at
    add_index :articles, :original_article_id
  end
end
