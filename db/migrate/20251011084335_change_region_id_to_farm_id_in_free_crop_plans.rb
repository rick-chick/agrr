class ChangeRegionIdToFarmIdInFreeCropPlans < ActiveRecord::Migration[8.0]
  def change
    # region_idをfarm_idに変更
    remove_foreign_key :free_crop_plans, :regions, if_exists: true
    remove_index :free_crop_plans, :region_id, if_exists: true
    
    rename_column :free_crop_plans, :region_id, :farm_id
    
    add_index :free_crop_plans, :farm_id
    add_foreign_key :free_crop_plans, :farms
  end
end
