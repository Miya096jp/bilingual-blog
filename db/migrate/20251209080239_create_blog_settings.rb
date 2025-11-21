class CreateBlogSettings < ActiveRecord::Migration[8.0]
  def change
    create_table :blog_settings do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string :blog_title
      t.string :blog_subtitle
      t.string :theme_color, default: 'blue'

      t.timestamps
    end
  end
end
