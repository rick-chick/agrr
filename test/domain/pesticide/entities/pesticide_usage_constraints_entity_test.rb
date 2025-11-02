# frozen_string_literal: true

require "test_helper"

module Domain
  module Pesticide
    module Entities
      class PesticideUsageConstraintsEntityTest < ActiveSupport::TestCase
        test "should initialize with valid attributes" do
          entity = PesticideUsageConstraintsEntity.new(
            id: 1,
            pesticide_id: 1,
            min_temperature: 5.0,
            max_temperature: 35.0,
            max_wind_speed_m_s: 3.0,
            max_application_count: 3,
            harvest_interval_days: 1,
            other_constraints: nil,
            created_at: Time.current,
            updated_at: Time.current
          )

          assert_equal 1, entity.id
          assert_equal 1, entity.pesticide_id
          assert_equal 5.0, entity.min_temperature
          assert_equal 35.0, entity.max_temperature
          assert_equal 3.0, entity.max_wind_speed_m_s
          assert_equal 3, entity.max_application_count
          assert_equal 1, entity.harvest_interval_days
        end

        test "should initialize with nil values" do
          entity = PesticideUsageConstraintsEntity.new(
            id: 1,
            pesticide_id: 1,
            min_temperature: nil,
            max_temperature: nil,
            max_wind_speed_m_s: nil,
            max_application_count: nil,
            harvest_interval_days: nil,
            other_constraints: nil,
            created_at: Time.current,
            updated_at: Time.current
          )

          assert_nil entity.min_temperature
          assert_nil entity.max_temperature
          assert_nil entity.max_wind_speed_m_s
        end

        test "should raise error when pesticide_id is blank" do
          assert_raises(ArgumentError, "Pesticide ID is required") do
            PesticideUsageConstraintsEntity.new(
              id: 1,
              pesticide_id: nil,
              min_temperature: nil,
              max_temperature: nil,
              max_wind_speed_m_s: nil,
              max_application_count: nil,
              harvest_interval_days: nil,
              other_constraints: nil,
              created_at: Time.current,
              updated_at: Time.current
            )
          end
        end

        test "should raise error when min_temperature is greater than max_temperature" do
          assert_raises(ArgumentError, "Min temperature must be less than max temperature") do
            PesticideUsageConstraintsEntity.new(
              id: 1,
              pesticide_id: 1,
              min_temperature: 40.0,
              max_temperature: 35.0,
              max_wind_speed_m_s: nil,
              max_application_count: nil,
              harvest_interval_days: nil,
              other_constraints: nil,
              created_at: Time.current,
              updated_at: Time.current
            )
          end
        end

        test "should allow min_temperature equal to max_temperature" do
          entity = PesticideUsageConstraintsEntity.new(
            id: 1,
            pesticide_id: 1,
            min_temperature: 20.0,
            max_temperature: 20.0,
            max_wind_speed_m_s: nil,
            max_application_count: nil,
            harvest_interval_days: nil,
            other_constraints: nil,
            created_at: Time.current,
            updated_at: Time.current
          )

          assert_equal 20.0, entity.min_temperature
          assert_equal 20.0, entity.max_temperature
        end

        test "should raise error when max_wind_speed_m_s is negative" do
          assert_raises(ArgumentError, "Max wind speed must be positive") do
            PesticideUsageConstraintsEntity.new(
              id: 1,
              pesticide_id: 1,
              min_temperature: nil,
              max_temperature: nil,
              max_wind_speed_m_s: -1.0,
              max_application_count: nil,
              harvest_interval_days: nil,
              other_constraints: nil,
              created_at: Time.current,
              updated_at: Time.current
            )
          end
        end

        test "should raise error when max_application_count is less than 1" do
          assert_raises(ArgumentError, "Max application count must be positive") do
            PesticideUsageConstraintsEntity.new(
              id: 1,
              pesticide_id: 1,
              min_temperature: nil,
              max_temperature: nil,
              max_wind_speed_m_s: nil,
              max_application_count: 0,
              harvest_interval_days: nil,
              other_constraints: nil,
              created_at: Time.current,
              updated_at: Time.current
            )
          end
        end

        test "should raise error when harvest_interval_days is negative" do
          assert_raises(ArgumentError, "Harvest interval must be non-negative") do
            PesticideUsageConstraintsEntity.new(
              id: 1,
              pesticide_id: 1,
              min_temperature: nil,
              max_temperature: nil,
              max_wind_speed_m_s: nil,
              max_application_count: nil,
              harvest_interval_days: -1,
              other_constraints: nil,
              created_at: Time.current,
              updated_at: Time.current
            )
          end
        end

        test "has_temperature_constraints? should return true when min_temperature is present" do
          entity = PesticideUsageConstraintsEntity.new(
            id: 1,
            pesticide_id: 1,
            min_temperature: 5.0,
            max_temperature: nil,
            max_wind_speed_m_s: nil,
            max_application_count: nil,
            harvest_interval_days: nil,
            other_constraints: nil,
            created_at: Time.current,
            updated_at: Time.current
          )

          assert entity.has_temperature_constraints?
        end

        test "has_temperature_constraints? should return true when max_temperature is present" do
          entity = PesticideUsageConstraintsEntity.new(
            id: 1,
            pesticide_id: 1,
            min_temperature: nil,
            max_temperature: 35.0,
            max_wind_speed_m_s: nil,
            max_application_count: nil,
            harvest_interval_days: nil,
            other_constraints: nil,
            created_at: Time.current,
            updated_at: Time.current
          )

          assert entity.has_temperature_constraints?
        end

        test "has_temperature_constraints? should return false when both are nil" do
          entity = PesticideUsageConstraintsEntity.new(
            id: 1,
            pesticide_id: 1,
            min_temperature: nil,
            max_temperature: nil,
            max_wind_speed_m_s: nil,
            max_application_count: nil,
            harvest_interval_days: nil,
            other_constraints: nil,
            created_at: Time.current,
            updated_at: Time.current
          )

          assert_not entity.has_temperature_constraints?
        end

        test "has_wind_constraints? should return true when max_wind_speed_m_s is present" do
          entity = PesticideUsageConstraintsEntity.new(
            id: 1,
            pesticide_id: 1,
            min_temperature: nil,
            max_temperature: nil,
            max_wind_speed_m_s: 3.0,
            max_application_count: nil,
            harvest_interval_days: nil,
            other_constraints: nil,
            created_at: Time.current,
            updated_at: Time.current
          )

          assert entity.has_wind_constraints?
        end

        test "has_wind_constraints? should return false when max_wind_speed_m_s is nil" do
          entity = PesticideUsageConstraintsEntity.new(
            id: 1,
            pesticide_id: 1,
            min_temperature: nil,
            max_temperature: nil,
            max_wind_speed_m_s: nil,
            max_application_count: nil,
            harvest_interval_days: nil,
            other_constraints: nil,
            created_at: Time.current,
            updated_at: Time.current
          )

          assert_not entity.has_wind_constraints?
        end
      end
    end
  end
end

