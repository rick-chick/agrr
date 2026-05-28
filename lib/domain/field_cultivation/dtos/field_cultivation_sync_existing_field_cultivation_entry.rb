# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Dtos
      # 同期前の field_cultivation 1 行（allocation_id から plan_crop を解決するため）。
      class FieldCultivationSyncExistingFieldCultivationEntry
        attr_reader :field_cultivation_id, :cultivation_plan_crop_id, :crop_id

        def initialize(field_cultivation_id:, cultivation_plan_crop_id:, crop_id:)
          @field_cultivation_id = field_cultivation_id
          @cultivation_plan_crop_id = cultivation_plan_crop_id
          @crop_id = crop_id.to_s
          freeze
        end
      end
    end
  end
end
