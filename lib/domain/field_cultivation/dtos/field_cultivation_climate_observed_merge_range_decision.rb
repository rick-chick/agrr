# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Dtos
      class FieldCultivationClimateObservedMergeRangeDecision
        attr_reader :start_date, :end_date

        def initialize(skip:, start_date: nil, end_date: nil)
          @skip = skip
          @start_date = start_date
          @end_date = end_date
          freeze
        end

        def skip?
          @skip
        end

        def self.skip
          new(skip: true)
        end

        def self.range(start_date:, end_date:)
          new(skip: false, start_date: start_date, end_date: end_date)
        end
      end
    end
  end
end
