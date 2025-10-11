class AddIsAnonymousToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :is_anonymous, :boolean, default: false, null: false
    
    # アノニマスユーザーの場合、email、name、google_idはnullを許可する必要がある
    change_column_null :users, :email, true
    change_column_null :users, :name, true
    change_column_null :users, :google_id, true
    
    # インデックスも修正（ユニーク制約はnullを許可する）
    remove_index :users, :email
    remove_index :users, :google_id
    add_index :users, :email, unique: true, where: "is_anonymous = false"
    add_index :users, :google_id, unique: true, where: "is_anonymous = false"
  end
end
