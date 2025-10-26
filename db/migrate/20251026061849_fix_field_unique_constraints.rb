# frozen_string_literal: true

class FixFieldUniqueConstraints < ActiveRecord::Migration[8.0]
  def up
    # 既存のユニーク制約を削除
    remove_index :fields, name: "index_fields_on_farm_id_and_name"
    remove_index :fields, name: "index_fields_on_user_id_and_name"
    
    # 正しいユニーク制約を追加（user_id, farm_id, name の組み合わせ）
    add_index :fields, [:user_id, :farm_id, :name], unique: true, name: "index_fields_on_user_id_and_farm_id_and_name"
    
    # パフォーマンス用のインデックスも追加
    add_index :fields, [:farm_id, :name], name: "index_fields_on_farm_id_and_name"
  end
  
  def down
    # 新しいユニーク制約を削除
    remove_index :fields, name: "index_fields_on_user_id_and_farm_id_and_name"
    remove_index :fields, name: "index_fields_on_farm_id_and_name"
    
    # 元のユニーク制約を復元
    add_index :fields, [:farm_id, :name], unique: true, name: "index_fields_on_farm_id_and_name"
    add_index :fields, [:user_id, :name], unique: true, name: "index_fields_on_user_id_and_name"
  end
end