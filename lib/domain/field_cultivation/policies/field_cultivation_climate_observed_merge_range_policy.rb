# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Policies
      module FieldCultivationClimateObservedMergeRangePolicy
        module_function

        # @param today [Date]
        # @return [Domain::FieldCultivation::Dtos::FieldCultivationClimateObservedMergeRangeDecision]
        def resolve(cultivation_start_date:, cultivation_end_date:, today:)
          mapper = Domain::FieldCultivation::Mappers::FieldCultivationClimateWeatherPayloadMapper
          observed_start = mapper.coerce_optional_date(cultivation_start_date)
          observed_end = mapper.coerce_optional_date(cultivation_end_date)

          return Dtos::FieldCultivationClimateObservedMergeRangeDecision.skip if observed_start.nil? || observed_end.nil?

          actual_end = [ observed_end, today - 1 ].min
          return Dtos::FieldCultivationClimateObservedMergeRangeDecision.skip if observed_start > actual_end

          Dtos::FieldCultivationClimateObservedMergeRangeDecision.range(
            start_date: observed_start,
            end_date: actual_end
          )
        end
      end
    end
  end
end
