# frozen_string_literal: true

require "test_helper"

module Domain
  module AgriculturalTask
    module Entities
      class AgriculturalTaskEntityTest < ActiveSupport::TestCase
        test "should initialize with valid attributes" do
          entity = AgriculturalTaskEntity.new(
            id: 1,
            user_id: 1,
            name: "Test Task",
            description: "Test description",
            time_per_sqm: 0.5,
            weather_dependency: "sunny",
            required_tools: ["tool1", "tool2"],
            skill_level: "beginner",
            region: "jp",
            task_type: "planting",
            is_reference: true,
            created_at: Time.current,
            updated_at: Time.current
          )

          assert_equal 1, entity.id
          assert_equal 1, entity.user_id
          assert_equal "Test Task", entity.name
          assert_equal "Test description", entity.description
          assert_equal 0.5, entity.time_per_sqm
          assert_equal "sunny", entity.weather_dependency
          assert_equal ["tool1", "tool2"], entity.required_tools
          assert_equal "beginner", entity.skill_level
          assert_equal "jp", entity.region
          assert_equal "planting", entity.task_type
          assert entity.reference?
        end

        test "should initialize with nil region" do
          entity = AgriculturalTaskEntity.new(
            id: 1,
            user_id: 1,
            name: "Test Task",
            description: "Test description",
            time_per_sqm: 0.5,
            weather_dependency: "sunny",
            required_tools: [],
            skill_level: "beginner",
            region: nil,
            task_type: "planting",
            is_reference: true,
            created_at: Time.current,
            updated_at: Time.current
          )

          assert_nil entity.region
        end

        test "should raise error when name is blank" do
          assert_raises(ArgumentError, "Name is required") do
            AgriculturalTaskEntity.new(
              id: 1,
              user_id: 1,
              name: "",
              description: "Test description",
              time_per_sqm: 0.5,
              weather_dependency: "sunny",
              required_tools: [],
              skill_level: "beginner",
              region: "jp",
              task_type: "planting",
              is_reference: true,
              created_at: Time.current,
              updated_at: Time.current
            )
          end
        end

        test "should raise error when region is invalid" do
          assert_raises(ArgumentError, "Region must be one of: jp, us, in") do
            AgriculturalTaskEntity.new(
              id: 1,
              user_id: 1,
              name: "Test Task",
              description: "Test description",
              time_per_sqm: 0.5,
              weather_dependency: "sunny",
              required_tools: [],
              skill_level: "beginner",
              region: "invalid",
              task_type: "planting",
              is_reference: true,
              created_at: Time.current,
              updated_at: Time.current
            )
          end
        end

        test "should accept valid regions jp, us, in" do
          %w[jp us in].each do |valid_region|
            entity = AgriculturalTaskEntity.new(
              id: 1,
              user_id: 1,
              name: "Test Task",
              description: "Test description",
              time_per_sqm: 0.5,
              weather_dependency: "sunny",
              required_tools: [],
              skill_level: "beginner",
              region: valid_region,
              task_type: "planting",
              is_reference: true,
              created_at: Time.current,
              updated_at: Time.current
            )

            assert_equal valid_region, entity.region
          end
        end

        test "reference? should return true for reference tasks" do
          entity = AgriculturalTaskEntity.new(
            id: 1,
            user_id: 1,
            name: "Test Task",
            description: "Test description",
            time_per_sqm: 0.5,
            weather_dependency: "sunny",
            required_tools: [],
            skill_level: "beginner",
            region: "jp",
            task_type: "planting",
            is_reference: true,
            created_at: Time.current,
            updated_at: Time.current
          )

          assert entity.reference?
        end

        test "reference? should return false for non-reference tasks" do
          entity = AgriculturalTaskEntity.new(
            id: 1,
            user_id: 1,
            name: "Test Task",
            description: "Test description",
            time_per_sqm: 0.5,
            weather_dependency: "sunny",
            required_tools: [],
            skill_level: "beginner",
            region: "jp",
            task_type: "planting",
            is_reference: false,
            created_at: Time.current,
            updated_at: Time.current
          )

          assert_not entity.reference?
        end
      end
    end
  end
end