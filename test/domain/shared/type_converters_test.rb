# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Shared
    class TypeConvertersTest < DomainLibTestCase
      test "IntegerConverter.cast yields integer for digit strings and rejects non-digits" do
        assert_equal 42, TypeConverters::IntegerConverter.cast("42")
        assert_equal(-3, TypeConverters::IntegerConverter.cast("-3"))
        assert_nil TypeConverters::IntegerConverter.cast("12.5")
        assert_nil TypeConverters::IntegerConverter.cast(nil)
        assert_equal 7, TypeConverters::IntegerConverter.cast(7)
      end

      test "BigDecimalConverter.cast preserves BigDecimal and handles empty as nil" do
        bd = BigDecimal("1.25")
        assert_equal bd, TypeConverters::BigDecimalConverter.cast(bd)
        assert_equal BigDecimal("3"), TypeConverters::BigDecimalConverter.cast("3")
        assert_nil TypeConverters::BigDecimalConverter.cast(nil)
        assert_nil TypeConverters::BigDecimalConverter.cast("")
      end
    end
  end
end
