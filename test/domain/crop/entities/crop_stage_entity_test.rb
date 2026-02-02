# frozen_string_literal: true

require "test_helper"

module Domain
  module Crop
    module Entities
      class CropStageEntityTest < ActiveSupport::TestCase
        test "should initialize with valid attributes" do
          entity = CropStageEntity.new(
            id: 1,
            crop_id: 1,
            name: "種まき",
            order: 1,
            created_at: Time.current,
            updated_at: Time.current
          )
          assert_equal 1, entity.id
          assert_equal 1, entity.crop_id
          assert_equal "種まき", entity.name
          assert_equal 1, entity.order
          assert entity.created_at.present?
          assert entity.updated_at.present?
        end

        test "should initialize with nil optional attributes" do
          entity = CropStageEntity.new(
            id: nil,
            crop_id: 1,
            name: "種まき",
            order: 1,
            created_at: nil,
            updated_at: nil
          )
          assert_nil entity.id
          assert_equal 1, entity.crop_id
          assert_equal "種まき", entity.name
          assert_equal 1, entity.order
          assert_nil entity.created_at
          assert_nil entity.updated_at
        end

        test "should raise error when required attribute name is blank" do
          assert_raises(ArgumentError, "Name is required") do
            CropStageEntity.new(
              crop_id: 1,
              name: "",
              order: 1
            )
          end
        end

        test "should raise error when required attribute crop_id is nil" do
          assert_raises(ArgumentError, "Crop ID is required") do
            CropStageEntity.new(
              crop_id: nil,
              name: "種まき",
              order: 1
            )
          end
        end

        test "should raise error when required attribute order is nil" do
          assert_raises(ArgumentError, "Order is required") do
            CropStageEntity.new(
              crop_id: 1,
              name: "種まき",
              order: nil
            )
          end
        end
      end
    end
  end
end