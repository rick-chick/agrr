class AddIsDefaultToFarms < ActiveRecord::Migration[8.0]
  def change
    add_column :farms, :is_default, :boolean, default: false, null: false
    
    # デフォルト農場は1つだけ存在できる（部分ユニークインデックス）
    add_index :farms, :is_default, unique: true, where: "is_default = true", name: "index_farms_on_is_default_unique"
  end
end
