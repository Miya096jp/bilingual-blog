class AddLocalizeProfileFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    remove_column :users, :nickname, :string
    remove_column :users, :bio, :text
    remove_column :users, :location, :text

    add_column :users, :nickname_ja, :string
    add_column :users, :nickname_en, :string
    add_column :users, :bio_ja, :text
    add_column :users, :bio_en, :text
    add_column :users, :location_ja, :string
    add_column :users, :location_en, :string
  end
end
