# frozen_string_literal: true

class RemovePesticideIdFromPesticides < ActiveRecord::Migration[8.0]
  def change
    # pesticide_idを含むユニークインデックスを削除
    remove_index :pesticides, name: 'index_pesticides_on_crop_pest_pesticide_id' if index_exists?(:pesticides, [:crop_id, :pest_id, :pesticide_id], name: 'index_pesticides_on_crop_pest_pesticide_id')
    
    # pesticide_idの一意インデックスを削除
    remove_index :pesticides, :pesticide_id if index_exists?(:pesticides, :pesticide_id)
    
    # pesticide_idカラムを削除
    remove_column :pesticides, :pesticide_id, :string
  end
end
