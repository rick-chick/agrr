class RemoveUniqueConstraintFromFarmsIsDefault < ActiveRecord::Migration[8.0]
  def change
    # 複数のデフォルト農場を許可するため、ユニーク制約を削除
    remove_index :farms, name: "index_farms_on_is_default_unique", if_exists: true
    
    # デフォルト農場用のインデックスを追加（ユニークではない）
    add_index :farms, :is_default, where: "is_default = true"
  end
end
