# frozen_string_literal: true

class RemoveFieldAndCropReferencesFromFieldCultivations < ActiveRecord::Migration[8.0]
  def change
    # 後方互換性のために残していたfield_idとcrop_idを削除
    # 作付け計画ではcultivation_plan_fieldとcultivation_plan_cropのみを使用
    # Note: if_exists option to handle case where FK doesn't exist
    remove_reference :field_cultivations, :field, foreign_key: { on_delete: :nullify }, if_exists: true
    remove_reference :field_cultivations, :crop, foreign_key: true, if_exists: true
  end
end

