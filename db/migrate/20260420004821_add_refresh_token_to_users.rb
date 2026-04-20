class AddRefreshTokenToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :refresh_token, :string
    add_column :users, :refresh_token_expires_at, :datetime
    add_index :users, :refresh_token, unique: true unless index_exists?(:users, :refresh_token)
  end
end
