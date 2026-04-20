# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      module EntrySchedule
        # エントリ作物スケジュール用: 「まき」「植え」に相当する CropStage を解決する（docs/planning/crop_schedule_stage_roles.md）
        # T-035: app/services/crop_schedule から domain へ移行。
        class StageRoleResolver
          TRANSPLANT_NAME_PATTERN = /定植|植え付/

          class << self
            # @param crop [Crop]
            # @return [CropStage, nil]
            def sowing_stage(crop)
              stages = ordered_stages(crop)
              stages.first
            end

            # @param crop [Crop]
            # @return [CropStage, nil]
            def transplant_stage(crop)
              stages = ordered_stages(crop)
              return nil if stages.empty?

              by_name = stages.find { |s| s.name.to_s.match?(TRANSPLANT_NAME_PATTERN) }
              return by_name if by_name

              stages.second
            end

            private

            def ordered_stages(crop)
              crop.crop_stages.includes(:temperature_requirement).order(:order).to_a
            end
          end
        end
      end
    end
  end
end
