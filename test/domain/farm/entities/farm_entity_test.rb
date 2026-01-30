# frozen_string_literal: true

require "test_helper"

module Domain
  module Farm
    module Entities
      class FarmEntityTest < ActiveSupport::TestCase
        test "should initialize with valid attributes" do
          entity = FarmEntity.new(
            id: 1,
            name: "Test Farm",
            latitude: 35.0,
            longitude: 135.0,
            region: "Kyoto",
            user_id: 1,
            created_at: Time.current,
            updated_at: Time.current,
            is_reference: false
          )

          assert_equal 1, entity.id
          assert_equal "Test Farm", entity.name
          assert_equal 35.0, entity.latitude
          assert_equal 135.0, entity.longitude
          assert_equal "Kyoto", entity.region
          assert_equal 1, entity.user_id
          assert_not entity.reference?
        end

        test "should return coordinates array" do
          entity = FarmEntity.new(
            id: 1,
            name: "Test Farm",
            latitude: 35.0,
            longitude: 135.0,
            region: "Kyoto",
            user_id: 1,
            created_at: Time.current,
            updated_at: Time.current,
            is_reference: false
          )

          assert_equal [35.0, 135.0], entity.coordinates
        end

        test "has_coordinates? should return true when both latitude and longitude are present" do
          entity = FarmEntity.new(
            id: 1,
            name: "Test Farm",
            latitude: 35.0,
            longitude: 135.0,
            region: "Kyoto",
            user_id: 1,
            created_at: Time.current,
            updated_at: Time.current,
            is_reference: false
          )

          assert entity.has_coordinates?
        end

        test "has_coordinates? should return false when latitude is nil" do
          entity = FarmEntity.new(
            id: 1,
            name: "Test Farm",
            latitude: nil,
            longitude: 135.0,
            region: "Kyoto",
            user_id: 1,
            created_at: Time.current,
            updated_at: Time.current,
            is_reference: false
          )

          assert_not entity.has_coordinates?
        end

        test "has_coordinates? should return false when longitude is nil" do
          entity = FarmEntity.new(
            id: 1,
            name: "Test Farm",
            latitude: 35.0,
            longitude: nil,
            region: "Kyoto",
            user_id: 1,
            created_at: Time.current,
            updated_at: Time.current,
            is_reference: false
          )

          assert_not entity.has_coordinates?
        end

        test "display_name should return name when present" do
          entity = FarmEntity.new(
            id: 1,
            name: "Test Farm",
            latitude: 35.0,
            longitude: 135.0,
            region: "Kyoto",
            user_id: 1,
            created_at: Time.current,
            updated_at: Time.current,
            is_reference: false
          )

          assert_equal "Test Farm", entity.display_name
        end

        test "display_name should return fallback when name is blank" do
          entity = FarmEntity.new(
            id: 1,
            name: "",
            latitude: 35.0,
            longitude: 135.0,
            region: "Kyoto",
            user_id: 1,
            created_at: Time.current,
            updated_at: Time.current,
            is_reference: false
          )

          assert_equal "Farm 1", entity.display_name
        end

        test "reference? should return true for reference farms" do
          entity = FarmEntity.new(
            id: 1,
            name: "Test Farm",
            latitude: 35.0,
            longitude: 135.0,
            region: "Kyoto",
            user_id: 1,
            created_at: Time.current,
            updated_at: Time.current,
            is_reference: true
          )

          assert entity.reference?
        end

        test "from_hash should create entity from hash" do
          hash = {
            id: 1,
            name: "Test Farm",
            latitude: 35.0,
            longitude: 135.0,
            region: "Kyoto",
            user_id: 1,
            created_at: Time.current,
            updated_at: Time.current,
            is_reference: false
          }

          entity = FarmEntity.from_hash(hash)

          assert_equal 1, entity.id
          assert_equal "Test Farm", entity.name
        end
      end
    end
  end
end