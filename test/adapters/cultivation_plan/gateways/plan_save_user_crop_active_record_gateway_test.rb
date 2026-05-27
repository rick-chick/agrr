# frozen_string_literal: true

require "test_helper"

module Adapters
  module CultivationPlan
    module Gateways
      class PlanSaveUserCropActiveRecordGatewayTest < ActiveSupport::TestCase
        setup do
          @gateway = PlanSaveUserCropActiveRecordGateway.new
          @user = User.create!(
            email: "plan-save-crop-#{SecureRandom.hex(4)}@example.com",
            name: "Crop GW User",
            google_id: "plan-save-crop-#{SecureRandom.hex(8)}"
          )
          @reference = ::Crop.create!(
            user: nil,
            name: "参照作物",
            variety: "v",
            is_reference: true,
            area_per_unit: 0.2,
            revenue_per_area: 100.0,
            region: "jp"
          )
        end

        test "find_by_user_id_and_source_crop_id returns nil when missing" do
          assert_nil @gateway.find_by_user_id_and_source_crop_id(
            user_id: @user.id,
            source_crop_id: @reference.id
          )
        end

        test "create and find_by_user_id_and_source_crop_id round-trip" do
          created = @gateway.create(
            user_id: @user.id,
            attributes: {
              name: @reference.name,
              variety: @reference.variety,
              area_per_unit: @reference.area_per_unit,
              revenue_per_area: @reference.revenue_per_area,
              is_reference: false,
              region: @reference.region,
              source_crop_id: @reference.id
            }
          )

          found = @gateway.find_by_user_id_and_source_crop_id(
            user_id: @user.id,
            source_crop_id: @reference.id
          )
          assert_instance_of Domain::CultivationPlan::Dtos::PlanSaveUserCropSnapshot, created
          assert_instance_of Domain::CultivationPlan::Dtos::PlanSaveUserCropSnapshot, found
          assert_equal created.id, found.id
        end
      end
    end
  end
end
