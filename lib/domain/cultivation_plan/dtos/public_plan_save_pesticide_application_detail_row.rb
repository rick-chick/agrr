# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      class PublicPlanSavePesticideApplicationDetailRow
        attr_reader :dilution_ratio, :amount_per_m2, :amount_unit, :application_method

        def initialize(
          dilution_ratio: nil,
          amount_per_m2: nil,
          amount_unit: nil,
          application_method: nil
        )
          @dilution_ratio = dilution_ratio
          @amount_per_m2 = amount_per_m2
          @amount_unit = amount_unit
          @application_method = application_method
          freeze
        end
      end
    end
  end
end
