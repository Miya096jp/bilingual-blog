class AddShowHeroThumbnailToBlogSettings < ActiveRecord::Migration[8.0]
  def change
    add_column :blog_settings, :show_hero_thumbnail, :boolean, default: false
  end
end
