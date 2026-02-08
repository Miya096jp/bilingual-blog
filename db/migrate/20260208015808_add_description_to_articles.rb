class AddDescriptionToArticles < ActiveRecord::Migration[8.0]
  def change
    add_column :articles, :description, :text, null: false, default: ""
  end
end
