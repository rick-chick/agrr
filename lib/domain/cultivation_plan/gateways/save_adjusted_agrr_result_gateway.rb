# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Gateways
      # Agrr adjust 結果（field_schedules 等）を FieldCultivation と CultivationPlan サマリへ反映する。
      class SaveAdjustedAgrrResultGateway
        # @param plan_id [Integer]
        # @param result [Domain::CultivationPlan::Dtos::SaveAdjustedAgrrResultInput]
        # @return [void]
        # @raise 既存 concern と同様（I18n 文言の RuntimeError / ArgumentError 等）
        def save_adjust_result!(plan_id:, result:)
          raise NotImplementedError, "#{self.class} must implement save_adjust_result!"
        end
      end
    end
  end
end
