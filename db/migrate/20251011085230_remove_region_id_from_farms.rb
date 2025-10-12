class RemoveRegionIdFromFarms < ActiveRecord::Migration[8.0]
  def change
    # region_idに関連するインデックスを削除
    remove_index :farms, name: "index_farms_on_region_id_and_is_default_unique", if_exists: true
    remove_index :farms, column: :region_id, if_exists: true
    
    # 外部キー制約を削除
    remove_foreign_key :farms, :regions, if_exists: true
    
    # カラムを削除
    remove_column :farms, :region_id, :bigint, if_exists: true
  end
end
