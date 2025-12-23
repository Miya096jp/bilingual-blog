class CreateContacts < ActiveRecord::Migration[8.0]
  def change
    create_table :contacts do |t|
      t.string :name
      t.string :email
      t.string :subject
      t.text :message
      t.boolean :resolved, default: false

      t.timestamps
    end

    add_index :contacts, :resolved
    add_index :contacts, :created_at
  end
end
