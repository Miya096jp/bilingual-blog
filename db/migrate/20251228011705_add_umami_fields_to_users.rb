class AddUmamiFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :umami_website_id, :string
    add_column :users, :umami_share_url, :string
    add_column :users, :analytics_setup_completed, :boolean, default: false
  end
end
