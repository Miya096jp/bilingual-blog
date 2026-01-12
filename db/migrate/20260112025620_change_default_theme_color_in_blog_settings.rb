class ChangeDefaultThemeColorInBlogSettings < ActiveRecord::Migration[8.0]
  def change
    change_column_default :blog_settings, :theme_color, from: "slate", to: "default"
  end
end
