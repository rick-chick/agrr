# frozen_string_literal: true

class AddUserIdToPests < ActiveRecord::Migration[8.0]
  def up
    add_column :pests, :user_id, :integer
    add_index :pests, :user_id
    
    # 既存のデータでis_reference: falseかつuser_idがnilの場合は削除または修正
    # ただし、現時点では既存のユーザー害虫はない想定なので、is_reference: falseのデータは削除
    execute <<-SQL
      DELETE FROM pests WHERE is_reference = 0 AND user_id IS NULL;
    SQL
    
    add_foreign_key :pests, :users
  end

  def down
    remove_foreign_key :pests, :users
    remove_index :pests, :user_id
    remove_column :pests, :user_id
  end
end
