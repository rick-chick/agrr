# frozen_string_literal: true

require "test_helper"

module Domain
  module Pesticide
    module Entities
      class PesticideEntityTest < ActiveSupport::TestCase
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
            created_at: Time.current,
            updated_at: Time.current
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
            created_at: Time.current,
            updated_at: Time.current
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
              created_at: Time.current,
              updated_at: Time.current
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
              created_at: Time.current,
              updated_at: Time.current
            )
            assert_equal valid_region, entity.region
          end
        end

        test "should create entity from model" do
          record = mock
          record.stubs(:id).returns(1)
          record.stubs(:user_id).returns(2)
          record.stubs(:name).returns("Test Pesticide")
          record.stubs(:active_ingredient).returns("Test Ingredient")
          record.stubs(:description).returns("Test Description")
          record.stubs(:crop_id).returns(3)
          record.stubs(:pest_id).returns(4)
          record.stubs(:region).returns("jp")
          record.stubs(:is_reference).returns(false)
          record.stubs(:created_at).returns(Time.current)
          record.stubs(:updated_at).returns(Time.current)

          entity = PesticideEntity.from_model(record)
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
      end
    end
  end
end