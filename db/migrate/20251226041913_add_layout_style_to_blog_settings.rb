class AddLayoutStyleToBlogSettings < ActiveRecord::Migration[8.0]
  def change
    add_column :blog_settings, :layout_style, :string, default: 'linear'
  end
end
