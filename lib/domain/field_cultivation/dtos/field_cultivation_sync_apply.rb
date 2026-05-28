# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Dtos
      # 現行スナップショットと目標スナップショットの差分（Gateway が 1 トランザクションで適用）。
      class FieldCultivationSyncApply
        attr_reader :field_cultivations_to_update,
                    :field_cultivations_to_create,
                    :field_cultivation_ids_to_delete,
                    :cultivation_plan_crop_ids_to_delete,
                    :cultivation_plan_summary

        def initialize(
          field_cultivations_to_update:,
          field_cultivations_to_create:,
          field_cultivation_ids_to_delete:,
          cultivation_plan_crop_ids_to_delete:,
          cultivation_plan_summary:
        )
          @field_cultivations_to_update = Array(field_cultivations_to_update).freeze
          @field_cultivations_to_create = Array(field_cultivations_to_create).freeze
          @field_cultivation_ids_to_delete = Array(field_cultivation_ids_to_delete).freeze
          @cultivation_plan_crop_ids_to_delete = Array(cultivation_plan_crop_ids_to_delete).freeze
          @cultivation_plan_summary = cultivation_plan_summary
          freeze
        end
      end
    end
  end
end
