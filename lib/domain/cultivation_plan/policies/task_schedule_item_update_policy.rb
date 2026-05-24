# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Policies
      module TaskScheduleItemUpdatePolicy
        module_function

        # @param attributes_seed [Hash] 文字列キー
        # @param amount_snapshot [Domain::CultivationPlan::Dtos::TaskScheduleItemAmountSnapshot]
        # @param calculator [Domain::CultivationPlan::Calculators::AmountUnitConversionCalculator]
        # @param rescheduled_at [Time] 日付変更時に Gateway へ渡すタイムスタンプ（edge で注入）
        # @return [Hash] Gateway update 用（文字列キー）
        def build_update_attributes(attributes_seed:, amount_snapshot:, calculator:, rescheduled_at:)
          attributes = attributes_seed.transform_keys(&:to_s)
          if attributes.key?("scheduled_date") && attributes["scheduled_date"].present?
            new_date = Domain::CultivationPlan::Policies::TaskScheduleItemCreatePolicy.parse_scheduled_date!(
              attributes["scheduled_date"]
            )
            attributes["scheduled_date"] = new_date

            if amount_snapshot.scheduled_date != new_date
              attributes["rescheduled_at"] = rescheduled_at
              attributes["status"] = Domain::AgriculturalTask::Constants::TaskScheduleItemStatuses::RESCHEDULED
            end
          end

          converted = calculator.apply_to_update_attributes(
            attributes: attributes,
            current_amount: amount_snapshot.amount,
            current_unit: amount_snapshot.amount_unit,
            new_unit: attributes["amount_unit"],
            amount_param: attributes["amount"]
          )
          converted || attributes
        end
      end
    end
  end
end
