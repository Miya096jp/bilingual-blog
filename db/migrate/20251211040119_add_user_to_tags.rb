class AddUserToTags < ActiveRecord::Migration[8.0]
  def change
    add_reference :tags, :user, null: false, foreign_key: true

    remove_index :tags, :name
    add_index :tags, [ :name, :user_id ], unique: true
  end
end
