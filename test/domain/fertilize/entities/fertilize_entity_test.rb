# frozen_string_literal: true

require "test_helper"

module Domain
  module Fertilize
    module Entities
      class FertilizeEntityTest < ActiveSupport::TestCase
        test "should initialize with valid attributes" do
          entity = FertilizeEntity.new(
            id: 1,
            name: "尿素",
            n: 46.0,
            p: nil,
            k: nil,
            description: "窒素肥料",
            usage: "基肥・追肥",
            application_rate: "1㎡あたり10-30g",
            is_reference: true,
            created_at: Time.current,
            updated_at: Time.current
          )
          
          assert_equal 1, entity.id
          assert_equal "尿素", entity.name
          assert_equal 46.0, entity.n
          assert_nil entity.p
          assert_nil entity.k
          assert entity.reference?
        end

        test "should raise error when name is blank" do
          assert_raises(ArgumentError, "Name is required") do
            FertilizeEntity.new(
              id: 1,
              name: "",
              n: nil,
              p: nil,
              k: nil,
              description: nil,
              usage: nil,
              application_rate: nil,
              is_reference: true,
              created_at: Time.current,
              updated_at: Time.current
            )
          end
        end

        test "has_nutrient? should return true when nutrient is present and > 0" do
          entity = FertilizeEntity.new(
            id: 1,
            name: "尿素",
            n: 46.0,
            p: nil,
            k: nil,
            description: nil,
            usage: nil,
            application_rate: nil,
            is_reference: true,
            created_at: Time.current,
            updated_at: Time.current
          )
          
          assert entity.has_nutrient?(:n)
          assert_not entity.has_nutrient?(:p)
          assert_not entity.has_nutrient?(:k)
        end

        test "npk_summary should return formatted string" do
          entity = FertilizeEntity.new(
            id: 1,
            name: "配合肥料",
            n: 20.0,
            p: 10.0,
            k: 5.0,
            description: nil,
            usage: nil,
            application_rate: nil,
            is_reference: true,
            created_at: Time.current,
            updated_at: Time.current
          )
          
          assert_equal "20-10-5", entity.npk_summary
        end

        test "npk_summary should handle nil values" do
          entity = FertilizeEntity.new(
            id: 1,
            name: "尿素",
            n: 20.0,
            p: nil,
            k: 10.0,
            description: nil,
            usage: nil,
            application_rate: nil,
            is_reference: true,
            created_at: Time.current,
            updated_at: Time.current
          )
          
          assert_equal "20-10", entity.npk_summary
        end

        test "reference? should return true for reference fertilizes" do
          entity = FertilizeEntity.new(
            id: 1,
            name: "尿素",
            n: nil,
            p: nil,
            k: nil,
            description: nil,
            usage: nil,
            application_rate: nil,
            is_reference: true,
            created_at: Time.current,
            updated_at: Time.current
          )
          
          assert entity.reference?
        end
      end
    end
  end
end

