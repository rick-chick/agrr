# frozen_string_literal: true

require "test_helper"

module Domain
  module Pesticide
    module Entities
      class PesticideEntityTest < ActiveSupport::TestCase
        test "should initialize with valid attributes" do
          entity = PesticideEntity.new(
            id: 1,
            pesticide_id: "acetamiprid",
            crop_id: 1,
            pest_id: 1,
            name: "アセタミプリド",
            active_ingredient: "アセタミプリド",
            description: "浸透性殺虫剤",
            is_reference: true,
            created_at: Time.current,
            updated_at: Time.current
          )

          assert_equal 1, entity.id
          assert_equal "acetamiprid", entity.pesticide_id
          assert_equal "アセタミプリド", entity.name
          assert_equal "アセタミプリド", entity.active_ingredient
          assert_equal "浸透性殺虫剤", entity.description
          assert entity.reference?
        end

        test "should initialize with nil active_ingredient" do
          entity = PesticideEntity.new(
            id: 1,
            pesticide_id: "test_pesticide",
            crop_id: 1,
            pest_id: 1,
            name: "テスト農薬",
            active_ingredient: nil,
            description: nil,
            is_reference: false,
            created_at: Time.current,
            updated_at: Time.current
          )

          assert_nil entity.active_ingredient
          assert_not entity.reference?
        end

        test "should raise error when pesticide_id is blank" do
          assert_raises(ArgumentError, "Pesticide ID is required") do
            PesticideEntity.new(
              id: 1,
              pesticide_id: "",
              crop_id: 1,
              pest_id: 1,
              name: "テスト農薬",
              active_ingredient: nil,
              description: nil,
              is_reference: true,
              created_at: Time.current,
              updated_at: Time.current
            )
          end
        end

        test "should raise error when name is blank" do
          assert_raises(ArgumentError, "Name is required") do
            PesticideEntity.new(
              id: 1,
              pesticide_id: "test_pesticide",
              crop_id: 1,
              pest_id: 1,
              name: "",
              active_ingredient: nil,
              description: nil,
              is_reference: true,
              created_at: Time.current,
              updated_at: Time.current
            )
          end
        end

        test "should raise error when crop_id is blank" do
          assert_raises(ArgumentError, "Crop ID is required") do
            PesticideEntity.new(
              id: 1,
              pesticide_id: "test_pesticide",
              crop_id: nil,
              pest_id: 1,
              name: "テスト農薬",
              active_ingredient: nil,
              description: nil,
              is_reference: true,
              created_at: Time.current,
              updated_at: Time.current
            )
          end
        end

        test "should raise error when pest_id is blank" do
          assert_raises(ArgumentError, "Pest ID is required") do
            PesticideEntity.new(
              id: 1,
              pesticide_id: "test_pesticide",
              crop_id: 1,
              pest_id: nil,
              name: "テスト農薬",
              active_ingredient: nil,
              description: nil,
              is_reference: true,
              created_at: Time.current,
              updated_at: Time.current
            )
          end
        end

        test "reference? should return true for reference pesticides" do
          entity = PesticideEntity.new(
            id: 1,
            pesticide_id: "test_pesticide",
            crop_id: 1,
            pest_id: 1,
            name: "テスト農薬",
            active_ingredient: nil,
            description: nil,
            is_reference: true,
            created_at: Time.current,
            updated_at: Time.current
          )

          assert entity.reference?
        end

        test "reference? should return false for non-reference pesticides" do
          entity = PesticideEntity.new(
            id: 1,
            pesticide_id: "test_pesticide",
            crop_id: 1,
            pest_id: 1,
            name: "テスト農薬",
            active_ingredient: nil,
            description: nil,
            is_reference: false,
            created_at: Time.current,
            updated_at: Time.current
          )

          assert_not entity.reference?
        end

        test "display_name should return name when present" do
          entity = PesticideEntity.new(
            id: 1,
            pesticide_id: "test_pesticide",
            crop_id: 1,
            pest_id: 1,
            name: "テスト農薬",
            active_ingredient: nil,
            description: nil,
            is_reference: true,
            created_at: Time.current,
            updated_at: Time.current
          )

          assert_equal "テスト農薬", entity.display_name
        end
      end
    end
  end
end

