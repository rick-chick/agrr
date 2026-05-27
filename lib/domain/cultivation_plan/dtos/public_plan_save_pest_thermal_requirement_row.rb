# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      class PublicPlanSavePestThermalRequirementRow
        attr_reader :required_gdd, :first_generation_gdd

        def initialize(required_gdd:, first_generation_gdd:)
          @required_gdd = required_gdd
          @first_generation_gdd = first_generation_gdd
          freeze
        end
      end
    end
  end
end
