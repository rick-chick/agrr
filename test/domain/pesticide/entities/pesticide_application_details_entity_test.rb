# frozen_string_literal: true

require "test_helper"

module Domain
  module Pesticide
    module Entities
      class PesticideApplicationDetailsEntityTest < ActiveSupport::TestCase
        test "should initialize with valid attributes" do
          entity = PesticideApplicationDetailsEntity.new(
            id: 1,
            pesticide_id: 1,
            dilution_ratio: "1000倍",
            amount_per_m2: 0.1,
            amount_unit: "ml",
            application_method: "散布",
            created_at: Time.current,
            updated_at: Time.current
          )

          assert_equal 1, entity.id
          assert_equal 1, entity.pesticide_id
          assert_equal "1000倍", entity.dilution_ratio
          assert_equal 0.1, entity.amount_per_m2
          assert_equal "ml", entity.amount_unit
          assert_equal "散布", entity.application_method
        end

        test "should initialize with nil values" do
          entity = PesticideApplicationDetailsEntity.new(
            id: 1,
            pesticide_id: 1,
            dilution_ratio: nil,
            amount_per_m2: nil,
            amount_unit: nil,
            application_method: nil,
            created_at: Time.current,
            updated_at: Time.current
          )

          assert_nil entity.dilution_ratio
          assert_nil entity.amount_per_m2
          assert_nil entity.amount_unit
          assert_nil entity.application_method
        end

        test "should raise error when pesticide_id is blank" do
          assert_raises(ArgumentError, "Pesticide ID is required") do
            PesticideApplicationDetailsEntity.new(
              id: 1,
              pesticide_id: nil,
              dilution_ratio: nil,
              amount_per_m2: nil,
              amount_unit: nil,
              application_method: nil,
              created_at: Time.current,
              updated_at: Time.current
            )
          end
        end

        test "should raise error when amount_per_m2 is negative" do
          assert_raises(ArgumentError, "Amount per m2 must be positive") do
            PesticideApplicationDetailsEntity.new(
              id: 1,
              pesticide_id: 1,
              dilution_ratio: nil,
              amount_per_m2: -1.0,
              amount_unit: nil,
              application_method: nil,
              created_at: Time.current,
              updated_at: Time.current
            )
          end
        end

        test "should raise error when amount_unit is present but amount_per_m2 is nil" do
          assert_raises(ArgumentError, "Amount unit requires amount_per_m2") do
            PesticideApplicationDetailsEntity.new(
              id: 1,
              pesticide_id: 1,
              dilution_ratio: nil,
              amount_per_m2: nil,
              amount_unit: "ml",
              application_method: nil,
              created_at: Time.current,
              updated_at: Time.current
            )
          end
        end

        test "should raise error when amount_per_m2 is present but amount_unit is nil" do
          assert_raises(ArgumentError, "Amount per m2 requires amount_unit") do
            PesticideApplicationDetailsEntity.new(
              id: 1,
              pesticide_id: 1,
              dilution_ratio: nil,
              amount_per_m2: 0.1,
              amount_unit: nil,
              application_method: nil,
              created_at: Time.current,
              updated_at: Time.current
            )
          end
        end

        test "should allow amount_per_m2 and amount_unit both present" do
          entity = PesticideApplicationDetailsEntity.new(
            id: 1,
            pesticide_id: 1,
            dilution_ratio: nil,
            amount_per_m2: 0.1,
            amount_unit: "ml",
            application_method: nil,
            created_at: Time.current,
            updated_at: Time.current
          )

          assert_equal 0.1, entity.amount_per_m2
          assert_equal "ml", entity.amount_unit
        end

        test "should allow amount_per_m2 and amount_unit both nil" do
          entity = PesticideApplicationDetailsEntity.new(
            id: 1,
            pesticide_id: 1,
            dilution_ratio: nil,
            amount_per_m2: nil,
            amount_unit: nil,
            application_method: nil,
            created_at: Time.current,
            updated_at: Time.current
          )

          assert_nil entity.amount_per_m2
          assert_nil entity.amount_unit
        end

        test "has_amount? should return true when both amount_per_m2 and amount_unit are present" do
          entity = PesticideApplicationDetailsEntity.new(
            id: 1,
            pesticide_id: 1,
            dilution_ratio: nil,
            amount_per_m2: 0.1,
            amount_unit: "ml",
            application_method: nil,
            created_at: Time.current,
            updated_at: Time.current
          )

          assert entity.has_amount?
        end

        test "should raise error when amount_per_m2 is nil but amount_unit is present" do
          assert_raises(ArgumentError, "Amount unit requires amount_per_m2") do
            PesticideApplicationDetailsEntity.new(
              id: 1,
              pesticide_id: 1,
              dilution_ratio: nil,
              amount_per_m2: nil,
              amount_unit: "ml",
              application_method: nil,
              created_at: Time.current,
              updated_at: Time.current
            )
          end
        end

        test "should raise error when amount_unit is nil but amount_per_m2 is present" do
          assert_raises(ArgumentError, "Amount per m2 requires amount_unit") do
            PesticideApplicationDetailsEntity.new(
              id: 1,
              pesticide_id: 1,
              dilution_ratio: nil,
              amount_per_m2: 0.1,
              amount_unit: nil,
              application_method: nil,
              created_at: Time.current,
              updated_at: Time.current
            )
          end
        end

        test "has_amount? should return false when both are nil" do
          entity = PesticideApplicationDetailsEntity.new(
            id: 1,
            pesticide_id: 1,
            dilution_ratio: nil,
            amount_per_m2: nil,
            amount_unit: nil,
            application_method: nil,
            created_at: Time.current,
            updated_at: Time.current
          )

          assert_not entity.has_amount?
        end
      end
    end
  end
end

