# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Pesticide
    module Entities
      class PesticideEntityTest < DomainLibTestCase
        test "should initialize with valid attributes" do
          entity = PesticideEntity.new(
            id: 1,
            user_id: 2,
            name: "Test Pesticide",
            active_ingredient: "Test Ingredient",
            description: "Test Description",
            crop_id: 3,
            pest_id: 4,
            region: "jp",
            is_reference: false,
            created_at: Time.utc(2026, 1, 1),
            updated_at: Time.utc(2026, 1, 1)
          )
          assert_equal 1, entity.id
          assert_equal 2, entity.user_id
          assert_equal "Test Pesticide", entity.name
          assert_equal "Test Ingredient", entity.active_ingredient
          assert_equal "Test Description", entity.description
          assert_equal 3, entity.crop_id
          assert_equal 4, entity.pest_id
          assert_equal "jp", entity.region
          assert_equal false, entity.is_reference
        end

        test "should initialize with nil region" do
          entity = PesticideEntity.new(
            id: 1,
            user_id: 2,
            name: "Test Pesticide",
            region: nil,
            is_reference: false,
            created_at: Time.utc(2026, 1, 1),
            updated_at: Time.utc(2026, 1, 1)
          )
          assert_nil entity.region
        end

        test "should raise error when region is invalid" do
          assert_raises(ArgumentError, "Region must be one of: jp, us, in") do
            PesticideEntity.new(
              id: 1,
              user_id: 2,
              name: "Test Pesticide",
              region: "invalid",
              is_reference: false,
              created_at: Time.utc(2026, 1, 1),
              updated_at: Time.utc(2026, 1, 1)
            )
          end
        end

        test "should initialize with valid regions" do
          %w[jp us in].each do |valid_region|
            entity = PesticideEntity.new(
              id: 1,
              user_id: 2,
              name: "Test Pesticide",
              region: valid_region,
              is_reference: false,
              created_at: Time.utc(2026, 1, 1),
              updated_at: Time.utc(2026, 1, 1)
            )
            assert_equal valid_region, entity.region
          end
        end
      end
    end
  end
end
