# frozen_string_literal: true

class AddUserIdToPesticides < ActiveRecord::Migration[8.0]
  def up
    add_column :pesticides, :user_id, :integer
    add_index :pesticides, :user_id
    
    # 既存のデータでis_reference: falseかつuser_idがnilの場合は削除
    # ただし、現時点では既存のユーザー農薬はない想定なので、is_reference: falseのデータは削除
    execute <<-SQL
      DELETE FROM pesticides WHERE is_reference = 0 AND user_id IS NULL;
    SQL
    
    add_foreign_key :pesticides, :users
  end

  def down
    remove_foreign_key :pesticides, :users
    remove_index :pesticides, :user_id
    remove_column :pesticides, :user_id
  end
end




