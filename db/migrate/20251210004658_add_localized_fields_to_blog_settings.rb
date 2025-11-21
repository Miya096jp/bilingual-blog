class AddLocalizedFieldsToBlogSettings < ActiveRecord::Migration[8.0]
  def change
    rename_column :blog_settings, :blog_title, :blog_title_ja
    rename_column :blog_settings, :blog_subtitle, :blog_subtitle_ja

    add_column :blog_settings, :blog_title_en, :string
    add_column :blog_settings, :blog_subtitle_en, :string
  end
end
