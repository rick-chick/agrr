# frozen_string_literal: true

require "test_helper"

module Adapters
  module CultivationPlan
    module Gateways
      class PlanSaveUserPestActiveRecordGatewayTest < ActiveSupport::TestCase
        setup do
          @gateway = PlanSaveUserPestActiveRecordGateway.new
          @user = User.create!(
            email: "plan-save-pest-#{SecureRandom.hex(4)}@example.com",
            name: "Pest GW User",
            google_id: "plan-save-pest-#{SecureRandom.hex(8)}"
          )
          @reference = ::Pest.create!(
            user: nil,
            name: "参照害虫",
            is_reference: true,
            region: "jp"
          )
        end

        test "find_by_user_id_and_source_pest_id returns nil when missing" do
          assert_nil @gateway.find_by_user_id_and_source_pest_id(
            user_id: @user.id,
            source_pest_id: @reference.id
          )
        end

        test "create find and child records round-trip" do
          created = @gateway.create(
            user_id: @user.id,
            attributes: {
              name: @reference.name,
              is_reference: false,
              region: "jp",
              source_pest_id: @reference.id
            }
          )

          @gateway.create_temperature_profile(
            pest_id: created.id,
            attributes: { base_temperature: 10.0, max_temperature: 30.0 }
          )
          @gateway.create_control_method(
            pest_id: created.id,
            attributes: {
              method_type: "cultural",
              method_name: "防除",
              description: "d",
              timing_hint: "t"
            }
          )

          found = @gateway.find_by_user_id_and_source_pest_id(
            user_id: @user.id,
            source_pest_id: @reference.id
          )
          assert_equal created.id, found.id

          pest = ::Pest.find(created.id)
          assert_not_nil pest.pest_temperature_profile
          assert_equal 1, pest.pest_control_methods.count
        end

        test "link_crop_pest creates join row" do
          crop = @user.crops.create!(
            name: "作物",
            variety: "v",
            is_reference: false,
            area_per_unit: 0.2,
            revenue_per_area: 100.0,
            region: "jp"
          )
          pest = @gateway.create(
            user_id: @user.id,
            attributes: {
              name: "ユーザー害虫",
              is_reference: false,
              region: "jp",
              source_pest_id: @reference.id
            }
          )

          @gateway.link_crop_pest(crop_id: crop.id, pest_id: pest.id)
          assert CropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        end
      end
    end
  end
end
