# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Farm
    module Entities
      class FieldEntityTest < DomainLibTestCase
        test "should initialize with valid attributes" do
          entity = FieldEntity.new(
            id: 1,
            name: "Test Field",
            area: 100.0,
            daily_fixed_cost: 50.0,
            region: "Kyoto",
            farm_id: 1,
            user_id: 1,
            created_at: Time.utc(2026, 1, 1),
            updated_at: Time.utc(2026, 1, 1)
          )

          assert_equal 1, entity.id
          assert_equal "Test Field", entity.name
          assert_equal 100.0, entity.area
          assert_equal 50.0, entity.daily_fixed_cost
          assert_equal "Kyoto", entity.region
          assert_equal 1, entity.farm_id
          assert_equal 1, entity.user_id
        end

        test "display_name should return name when present" do
          entity = FieldEntity.new(
            id: 1,
            name: "Test Field",
            area: 100.0,
            daily_fixed_cost: 50.0,
            region: "Kyoto",
            farm_id: 1,
            user_id: 1,
            created_at: Time.utc(2026, 1, 1),
            updated_at: Time.utc(2026, 1, 1)
          )

          assert_equal "Test Field", entity.display_name
        end

        test "display_name should return fallback when name is blank" do
          entity = FieldEntity.new(
            id: 1,
            name: "",
            area: 100.0,
            daily_fixed_cost: 50.0,
            region: "Kyoto",
            farm_id: 1,
            user_id: 1,
            created_at: Time.utc(2026, 1, 1),
            updated_at: Time.utc(2026, 1, 1)
          )

          assert_equal "Field 1", entity.display_name
        end

        test "from_hash should create entity from hash" do
          hash = {
            id: 1,
            name: "Test Field",
            area: 100.0,
            daily_fixed_cost: 50.0,
            region: "Kyoto",
            farm_id: 1,
            user_id: 1,
            created_at: Time.utc(2026, 1, 1),
            updated_at: Time.utc(2026, 1, 1)
          }

          entity = FieldEntity.from_hash(hash)

          assert_equal 1, entity.id
          assert_equal "Test Field", entity.name
        end
      end
    end
  end
end
