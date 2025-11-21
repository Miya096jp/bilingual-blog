class AddSocialLinksToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :github_handle, :string
    add_column :users, :qiita_handle, :string
    add_column :users, :zenn_handle, :string
    add_column :users, :hatena_handle, :string
  end
end
