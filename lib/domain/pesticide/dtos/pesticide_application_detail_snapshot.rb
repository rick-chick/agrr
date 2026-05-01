# frozen_string_literal: true

module Domain
  module Pesticide
    module Dtos
      class PesticideApplicationDetailSnapshot
        attr_reader :dilution_ratio, :amount_per_m2, :amount_unit, :application_method

        def initialize(dilution_ratio:, amount_per_m2:, amount_unit:, application_method:)
          @dilution_ratio = dilution_ratio
          @amount_per_m2 = amount_per_m2
          @amount_unit = amount_unit
          @application_method = application_method
        end
      end
    end
  end
end
