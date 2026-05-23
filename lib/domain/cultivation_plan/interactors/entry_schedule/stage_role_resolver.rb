# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      module EntrySchedule
        # エントリ作物スケジュール用: 「まき」「植え」に相当する CropStage を解決する。
        # sowing = 最小 order、transplant = 名称に定植/植え付を含む stage、なければ 2 番目。
        # T-035: app/services/crop_schedule から domain へ移行。
        class StageRoleResolver
          TRANSPLANT_NAME_PATTERN = /定植|植え付/

          class << self
            # @param ordered_crop_stages [Array<#order, #name>] CropStageSnapshot 等（order 昇順であること）
            # @return [Object, nil]
            def sowing_stage(ordered_crop_stages)
              stages = Array(ordered_crop_stages).sort_by { |s| s.order.to_i }
              stages.first
            end

            # @param ordered_crop_stages [Array<#order, #name>]
            # @return [Object, nil]
            def transplant_stage(ordered_crop_stages)
              stages = Array(ordered_crop_stages).sort_by { |s| s.order.to_i }
              return nil if stages.empty?

              by_name = stages.find { |s| s.name.to_s.match?(TRANSPLANT_NAME_PATTERN) }
              return by_name if by_name

              stages.second
            end
          end
        end
      end
    end
  end
end
