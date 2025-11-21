class AddProfileFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :nickname, :string
    add_column :users, :bio, :text
    add_column :users, :website, :string
    add_column :users, :twitter_handle, :string
    add_column :users, :facebook_handle, :string
    add_column :users, :linkedin_handle, :string
    add_column :users, :location, :string
  end
end
