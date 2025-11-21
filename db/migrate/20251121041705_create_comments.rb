class CreateComments < ActiveRecord::Migration[8.0]
  def change
    create_table :comments do |t|
      t.references :article, null: false, foreign_key: true
      t.string :author_name, null: false
      t.text :content, null: false
      t.string :website

      t.timestamps
    end
  end
end
