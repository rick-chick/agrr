# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module CultivationPlan
    module Calculators
      class AmountUnitConversionCalculatorTest < DomainLibTestCase
        setup do
          @calculator = AmountUnitConversionCalculator.new
        end

        test "convert_per_area_amount converts kg/ha to g/m2" do
          result = @calculator.convert_per_area_amount(BigDecimal("1"), from: "kg/ha", to: "g/m2")
          assert_in_delta 0.1, result.to_f, 0.0001
        end

        test "apply_to_update_attributes converts when amount param matches current" do
          attrs = { "amount_unit" => "g/m2", "amount" => "1.0" }
          converted = @calculator.apply_to_update_attributes(
            attributes: attrs,
            current_amount: BigDecimal("1"),
            current_unit: "kg/ha",
            new_unit: "g/m2",
            amount_param: "1.0"
          )

          assert converted
          assert_in_delta 0.1, converted["amount"].to_f, 0.0001
        end

        test "apply_to_update_attributes returns nil when units match" do
          attrs = { "amount_unit" => "kg/ha" }
          assert_nil @calculator.apply_to_update_attributes(
            attributes: attrs,
            current_amount: BigDecimal("1"),
            current_unit: "kg/ha",
            new_unit: "kg/ha",
            amount_param: nil
          )
        end
      end
    end
  end
end
