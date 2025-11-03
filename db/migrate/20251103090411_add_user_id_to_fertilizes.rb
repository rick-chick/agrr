# frozen_string_literal: true

class AddUserIdToFertilizes < ActiveRecord::Migration[8.0]
  def up
    add_column :fertilizes, :user_id, :integer
    add_index :fertilizes, :user_id
    
    # 既存のデータでis_reference: falseかつuser_idがnilの場合は削除
    # （整合性のため）
    execute <<-SQL
      DELETE FROM fertilizes WHERE is_reference = 0 AND user_id IS NULL;
    SQL
  end
  
  def down
    remove_index :fertilizes, :user_id
    remove_column :fertilizes, :user_id
  end
end

