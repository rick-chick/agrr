# frozen_string_literal: true

require "test_helper"

module Adapters
  module CultivationPlan
    module Gateways
      class PlanSaveUserAgriculturalTaskActiveRecordGatewayTest < ActiveSupport::TestCase
        setup do
          @gateway = PlanSaveUserAgriculturalTaskActiveRecordGateway.new
          @user = User.create!(
            email: "plan-save-agtask-#{SecureRandom.hex(4)}@example.com",
            name: "AgTask GW User",
            google_id: "plan-save-agtask-#{SecureRandom.hex(8)}"
          )
          @reference = ::AgriculturalTask.create!(
            user: nil,
            name: "参照作業#{SecureRandom.hex(4)}",
            is_reference: true,
            region: "jp",
            time_per_sqm: 1.5
          )
          @crop = ::Crop.create!(
            user: @user,
            name: "ユーザー作物#{SecureRandom.hex(4)}",
            is_reference: false,
            area_per_unit: 0.25,
            revenue_per_area: 1000.0
          )
        end

        test "find_by_user_id_and_source_agricultural_task_id returns nil when missing" do
          assert_nil @gateway.find_by_user_id_and_source_agricultural_task_id(
            user_id: @user.id,
            source_agricultural_task_id: @reference.id
          )
        end

        test "create and find round-trip" do
          copy_name = "ユーザー作業#{SecureRandom.hex(4)}"
          created = @gateway.create(
            user_id: @user.id,
            attributes: {
              name: copy_name,
              time_per_sqm: 1.5,
              is_reference: false,
              region: "jp",
              source_agricultural_task_id: @reference.id,
              required_tools: []
            }
          )

          found = @gateway.find_by_user_id_and_source_agricultural_task_id(
            user_id: @user.id,
            source_agricultural_task_id: @reference.id
          )
          assert_instance_of Domain::CultivationPlan::Dtos::PlanSaveUserAgriculturalTaskSnapshot, created
          assert_instance_of Domain::CultivationPlan::Dtos::PlanSaveUserAgriculturalTaskSnapshot, found
          assert_equal created.id, found.id
          assert_equal copy_name, found.name
        end

        test "create_crop_task_template and find_crop_task_template round-trip" do
          task = @gateway.create(
            user_id: @user.id,
            attributes: {
              name: "紐づけ作業#{SecureRandom.hex(4)}",
              time_per_sqm: 2.0,
              is_reference: false,
              region: "jp",
              source_agricultural_task_id: @reference.id,
              required_tools: []
            }
          )

          assert_nil @gateway.find_crop_task_template(
            crop_id: @crop.id,
            agricultural_task_id: task.id
          )

          link = @gateway.create_crop_task_template(
            crop_id: @crop.id,
            agricultural_task_id: task.id,
            attributes: {
              name: task.name,
              time_per_sqm: task.name ? 2.0 : nil,
              is_reference: false,
              required_tools: []
            }
          )

          found = @gateway.find_crop_task_template(
            crop_id: @crop.id,
            agricultural_task_id: task.id
          )
          assert_instance_of Domain::CultivationPlan::Dtos::PlanSaveCropTaskTemplateLinkSnapshot, link
          assert_equal link.id, found.id
        end
      end
    end
  end
end
