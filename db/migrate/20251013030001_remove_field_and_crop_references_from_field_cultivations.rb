# frozen_string_literal: true

class RemoveFieldAndCropReferencesFromFieldCultivations < ActiveRecord::Migration[8.0]
  def up
    # field_idとcrop_idのカラムを削除（外部キー制約も自動削除される）
    if column_exists?(:field_cultivations, :field_id)
      remove_column :field_cultivations, :field_id
    end
    if column_exists?(:field_cultivations, :crop_id)
      remove_column :field_cultivations, :crop_id
    end
  end
  
  def down
    # ロールバック時は再度カラムを追加
    add_reference :field_cultivations, :field, foreign_key: { on_delete: :nullify }
    add_reference :field_cultivations, :crop, foreign_key: true
  end
end

