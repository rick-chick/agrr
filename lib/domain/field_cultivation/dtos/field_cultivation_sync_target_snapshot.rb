# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Dtos
      # 同期後に計画が持つべき field_cultivation 集合（参照 ID 解決済み）。
      class FieldCultivationSyncTargetSnapshot
        attr_reader :field_cultivation_rows,
                    :cultivation_plan_summary,
                    :referenced_crop_ids

        def initialize(field_cultivation_rows:, cultivation_plan_summary:, referenced_crop_ids:)
          @field_cultivation_rows = Array(field_cultivation_rows).freeze
          @cultivation_plan_summary = cultivation_plan_summary
          @referenced_crop_ids = Array(referenced_crop_ids).freeze
          freeze
        end
      end
    end
  end
end
