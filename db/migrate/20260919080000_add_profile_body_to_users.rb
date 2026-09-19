class AddProfileBodyToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :profile_body_ja, :text
    add_column :users, :profile_body_en, :text
  end
end
