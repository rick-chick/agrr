# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Calculators
      class AmountUnitConversionCalculator
        AMOUNT_NUMERATOR_UNITS = {
          "ml" => { base: :liter, factor: BigDecimal("0.001") },
          "l" => { base: :liter, factor: BigDecimal("1") },
          "g" => { base: :gram, factor: BigDecimal("1") },
          "kg" => { base: :gram, factor: BigDecimal("1000") }
        }.freeze

        AREA_UNITS = {
          "m2" => BigDecimal("1"),
          "㎡" => BigDecimal("1"),
          "a" => BigDecimal("100"),
          "10a" => BigDecimal("1000"),
          "ha" => BigDecimal("10000")
        }.freeze

        CONVERSION_TOLERANCE = BigDecimal("0.0001")
        private_constant :CONVERSION_TOLERANCE

        class UnitConversionError < StandardError; end

        # @param current_amount [Numeric, String, nil]
        # @param current_unit [String, nil]
        # @param new_unit [String, nil]
        # @param amount_param [Numeric, String, nil] 更新リクエストの amount（未送信なら nil）
        # @return [Hash, nil] amount キーを上書きした attributes のコピー。変換不要・不可なら nil
        def apply_to_update_attributes(attributes:, current_amount:, current_unit:, new_unit:, amount_param:)
          attrs = attributes.transform_keys(&:to_s)
          return nil unless attrs.key?("amount_unit")

          return nil if new_unit.blank? || current_unit.blank? || new_unit == current_unit
          return nil if current_amount.nil?

          if amount_param.present?
            param_amount = decimal_from(amount_param)
            return nil if param_amount.nil?
            return nil unless approx_equal?(param_amount, decimal_from(current_amount))
          end

          converted = convert_per_area_amount(
            decimal_from(current_amount),
            from: current_unit,
            to: new_unit
          )
          attrs.merge("amount" => converted)
        rescue UnitConversionError
          nil
        end

        def convert_per_area_amount(amount, from:, to:)
          amount = decimal_from(amount)
          raise UnitConversionError, "amount is required for conversion" if amount.nil?

          from_numerator, from_area = parse_per_area_unit(from)
          to_numerator, to_area = parse_per_area_unit(to)

          from_meta = AMOUNT_NUMERATOR_UNITS[from_numerator]
          to_meta = AMOUNT_NUMERATOR_UNITS[to_numerator]

          raise UnitConversionError, "unsupported amount unit: #{from}" if from_meta.nil?
          raise UnitConversionError, "unsupported amount unit: #{to}" if to_meta.nil?
          unless from_meta[:base] == to_meta[:base]
            raise UnitConversionError, "incompatible amount units: #{from} -> #{to}"
          end

          from_area_factor = area_unit_factor(from_area)
          to_area_factor = area_unit_factor(to_area)

          amount_in_base = amount * from_meta[:factor]
          amount_per_m2 = amount_in_base / from_area_factor
          target_in_base = amount_per_m2 * to_area_factor
          target_in_base / to_meta[:factor]
        end

        private

        def parse_per_area_unit(unit)
          parts = unit.to_s.split("/")
          raise UnitConversionError, "invalid amount_unit format: #{unit}" if parts.size != 2

          [ normalize_amount_unit(parts[0]), normalize_area_unit(parts[1]) ]
        end

        def normalize_amount_unit(unit)
          unit.to_s.strip.downcase
        end

        def normalize_area_unit(unit)
          value = unit.to_s.strip.downcase
          return "m2" if value == "㎡"

          value
        end

        def area_unit_factor(unit)
          factor = AREA_UNITS[normalize_area_unit(unit)]
          raise UnitConversionError, "unsupported area unit: #{unit}" if factor.nil?

          factor
        end

        def decimal_from(value)
          BigDecimal(value.to_s)
        rescue ArgumentError, TypeError
          nil
        end

        def approx_equal?(left, right)
          return false if left.nil? || right.nil?

          (left - right).abs <= CONVERSION_TOLERANCE
        end
      end
    end
  end
end
