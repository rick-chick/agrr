# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Policies
      module FieldCultivationClimateObservedMergeRangePolicy
        module_function

        # @param today [Date]
        # @return [Domain::FieldCultivation::Dtos::FieldCultivationClimateObservedMergeRangeDecision]
        def resolve(
          display_start_date:,
          display_end_date:,
          cultivation_start_date:,
          cultivation_end_date:,
          today:
        )
          mapper = Domain::FieldCultivation::Mappers::FieldCultivationClimateWeatherPayloadMapper
          display_start = mapper.coerce_optional_date(display_start_date)
          display_end = mapper.coerce_optional_date(display_end_date)

          if display_start && display_end
            observed_start = display_start
            observed_end = display_end
          else
            observed_start = mapper.coerce_optional_date(cultivation_start_date)
            observed_end = mapper.coerce_optional_date(cultivation_end_date)
          end

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
