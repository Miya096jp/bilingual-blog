class AllowAnonymousLikes < ActiveRecord::Migration[8.0]
  def up
    add_column :likes, :visitor_token, :string
    change_column_null :likes, :user_id, true

    remove_index :likes, name: "index_likes_on_user_id_and_article_id"

    add_index :likes, [ :article_id, :user_id ], unique: true,
      where: "user_id IS NOT NULL",
      name: "index_likes_on_article_id_and_user_id"

    add_index :likes, [ :article_id, :visitor_token ], unique: true,
      where: "visitor_token IS NOT NULL",
      name: "index_likes_on_article_id_and_visitor_token"
  end

  def down
    remove_index :likes, name: "index_likes_on_article_id_and_visitor_token"
    remove_index :likes, name: "index_likes_on_article_id_and_user_id"

    add_index :likes, [ :user_id, :article_id ], unique: true,
      name: "index_likes_on_user_id_and_article_id"

    change_column_null :likes, :user_id, false
    remove_column :likes, :visitor_token, :string
  end
end
