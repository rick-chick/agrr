class RenameFarmIsDefaultToIsReference < ActiveRecord::Migration[8.0]
  def change
    # 古いインデックスを削除
    remove_index :farms, name: "index_farms_on_is_default", if_exists: true
    
    # is_defaultをis_referenceにリネーム
    rename_column :farms, :is_default, :is_reference
    
    # 新しいインデックスを追加
    add_index :farms, :is_reference, where: "is_reference = true", name: "index_farms_on_is_reference"
  end
end
