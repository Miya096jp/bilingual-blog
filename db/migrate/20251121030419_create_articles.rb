class CreateArticles < ActiveRecord::Migration[8.0]
  def change
    create_table :articles do |t|
      t.string :title, null: false
      t.text :content, null: false
      t.string :locale, null: false, default: 'ja'
      t.integer :original_article_id
      t.integer :status, default: 0
      t.datetime :published_at
      t.timestamps
    end
  end
end
