# frozen_string_literal: true

require "test_helper"

module Adapters
  module AgriculturalTask
    module Gateways
      class CropTaskTemplateActiveRecordGatewayTest < ActiveSupport::TestCase
        setup do
          @gateway = CropTaskTemplateActiveRecordGateway.new
          @crop = create(:crop, :user_owned)
        end

        test "create_detail persists template with given attributes" do
          user = @crop.user
          task = create(:agricultural_task, :user_owned, user: user, name: "元のタスク名")
          attrs = Domain::Crop::Dtos::CropTaskTemplatePersistAttributes.new(
            name: "カスタム名",
            description: "カスタム説明",
            time_per_sqm: 0.5,
            weather_dependency: "high",
            required_tools: [ "鍬" ],
            skill_level: "advanced"
          )

          assert_difference("CropTaskTemplate.count", 1) do
            entity = @gateway.create_detail(
              crop_id: @crop.id,
              agricultural_task_id: task.id,
              attributes: attrs
            )
            assert_equal @crop.id, entity.crop_id
            assert_equal task.id, entity.agricultural_task_id
            assert_equal "カスタム名", entity.name
          end
        end

        test "create_detail raises record invalid when validation fails" do
          user = @crop.user
          task = create(:agricultural_task, :user_owned, user: user)
          attrs = Domain::Crop::Dtos::CropTaskTemplatePersistAttributes.new(
            name: "",
            description: nil,
            time_per_sqm: nil,
            weather_dependency: nil,
            required_tools: [],
            skill_level: nil
          )

          assert_raises(Domain::Shared::Exceptions::RecordInvalid) do
            @gateway.create_detail(crop_id: @crop.id, agricultural_task_id: task.id, attributes: attrs)
          end
        end
      end
    end
  end
end
