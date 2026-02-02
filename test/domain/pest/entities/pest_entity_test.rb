# frozen_string_literal: true

require "test_helper"

module Domain
  module Pest
    module Entities
      class PestEntityTest < ActiveSupport::TestCase
        test "should initialize with valid attributes" do
          entity = PestEntity.new(
            id: 1,
            user_id: 123,
            name: "Test Pest",
            name_scientific: "Testus pestus",
            family: "Testidae",
            order: "Testales",
            description: "A test pest",
            occurrence_season: "Spring",
            region: "jp",
            is_reference: true,
            created_at: Time.current,
            updated_at: Time.current
          )
          assert_equal 1, entity.id
          assert_equal 123, entity.user_id
          assert_equal "Test Pest", entity.name
          assert_equal "Testus pestus", entity.name_scientific
          assert_equal "Testidae", entity.family
          assert_equal "Testales", entity.order
          assert_equal "A test pest", entity.description
          assert_equal "Spring", entity.occurrence_season
          assert_equal "jp", entity.region
          assert entity.reference?
        end

        test "should initialize with nil region" do
          entity = PestEntity.new(
            id: 1,
            user_id: 123,
            name: "Test Pest",
            name_scientific: "Testus pestus",
            family: "Testidae",
            order: "Testales",
            description: "A test pest",
            occurrence_season: "Spring",
            region: nil,
            is_reference: true,
            created_at: Time.current,
            updated_at: Time.current
          )
          assert_nil entity.region
        end

        test "should raise error when name is blank" do
          assert_raises(ArgumentError, "Name is required") do
            PestEntity.new(
              id: 1,
              name: "",
              region: "jp",
              is_reference: true,
              created_at: Time.current,
              updated_at: Time.current
            )
          end
        end

        test "should raise error when region is invalid" do
          assert_raises(ArgumentError, "Region must be one of: jp, us, in") do
            PestEntity.new(
              id: 1,
              name: "Test Pest",
              region: "invalid",
              is_reference: true,
              created_at: Time.current,
              updated_at: Time.current
            )
          end
        end

        test "should accept valid regions" do
          %w[jp us in].each do |valid_region|
            entity = PestEntity.new(
              id: 1,
              name: "Test Pest",
              region: valid_region,
              is_reference: true,
              created_at: Time.current,
              updated_at: Time.current
            )
            assert_equal valid_region, entity.region
          end
        end

        test "reference? returns true when is_reference is true" do
          entity = PestEntity.new(
            id: 1,
            name: "Test Pest",
            region: "jp",
            is_reference: true,
            created_at: Time.current,
            updated_at: Time.current
          )
          assert entity.reference?
        end

        test "reference? returns false when is_reference is false" do
          entity = PestEntity.new(
            id: 1,
            name: "Test Pest",
            region: "jp",
            is_reference: false,
            created_at: Time.current,
            updated_at: Time.current
          )
          refute entity.reference?
        end

        test "to_hash returns expected hash" do
          created_at = Time.current
          updated_at = Time.current
          entity = PestEntity.new(
            id: 1,
            user_id: 123,
            name: "Test Pest",
            name_scientific: "Testus pestus",
            family: "Testidae",
            order: "Testales",
            description: "A test pest",
            occurrence_season: "Spring",
            region: "jp",
            is_reference: true,
            created_at: created_at,
            updated_at: updated_at
          )

          expected_hash = {
            id: 1,
            name: "Test Pest",
            name_scientific: "Testus pestus",
            family: "Testidae",
            order: "Testales",
            description: "A test pest",
            occurrence_season: "Spring",
            is_reference: true,
            created_at: created_at,
            updated_at: updated_at
          }

          assert_equal expected_hash, entity.to_hash
        end
      end
    end
  end
end