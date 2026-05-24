# frozen_string_literal: true

require "test_helper"

module Adapters
  module Crop
    module Gateways
      class CropMemoryGatewayTest < ActiveSupport::TestCase
        def setup
          @gateway = CropMemoryGateway.new(
            deletion_undo_gateway: CompositionRoot.deletion_undo_gateway
          )
          @temperature_requirement_gateway = Adapters::Crop::Gateways::TemperatureRequirementMemoryGateway.new
          @thermal_requirement_gateway = Adapters::Crop::Gateways::ThermalRequirementMemoryGateway.new
          @sunshine_requirement_gateway = Adapters::Crop::Gateways::SunshineRequirementMemoryGateway.new
          @nutrient_requirement_gateway = Adapters::Crop::Gateways::NutrientRequirementMemoryGateway.new
          @crop = create(:crop)
        end

        # CropStage tests
        test "create_crop_stage creates a new crop stage" do
          dto = Domain::Crop::Dtos::CropStageCreateInput.new(
            crop_id: @crop.id,
            payload: { name: "Seedling", order: 1 }
          )

          result = @gateway.create_crop_stage(dto)

          assert_equal "Seedling", result.name
          assert_equal 1, result.order
          assert_equal @crop.id, result.crop_id
          assert result.id.present?
        end

        test "update_crop_stage updates an existing crop stage" do
          crop_stage = create(:crop_stage, crop: @crop)
          dto = Domain::Crop::Dtos::CropStageUpdateInput.new(
            crop_id: @crop.id,
            stage_id: crop_stage.id,
            payload: { name: "Updated Stage", order: 2 }
          )

          result = @gateway.update_crop_stage(crop_stage.id, dto)

          assert_equal "Updated Stage", result.name
          assert_equal 2, result.order
        end

        test "delete_crop_stage deletes an existing crop stage" do
          crop_stage = create(:crop_stage, crop: @crop)

          @gateway.delete_crop_stage(crop_stage.id)

          assert_raises ActiveRecord::RecordNotFound do
            ::CropStage.find(crop_stage.id)
          end
        end

        # TemperatureRequirement tests
        test "find_by_crop_stage_id returns temperature requirement if exists" do
          crop_stage = create(:crop_stage, crop: @crop)
          requirement = create(:temperature_requirement, crop_stage: crop_stage)

          result = @temperature_requirement_gateway.find_by_crop_stage_id(crop_stage.id)

          assert_equal requirement.id, result.id
          assert_equal requirement.base_temperature, result.base_temperature
        end

        test "find_by_crop_stage_id returns nil if not exists" do
          crop_stage = create(:crop_stage, crop: @crop)

          result = @temperature_requirement_gateway.find_by_crop_stage_id(crop_stage.id)

          assert_nil result
        end

        test "create_temperature_requirement creates a new requirement" do
          crop_stage = create(:crop_stage, crop: @crop)
          dto = Domain::Crop::Dtos::TemperatureRequirementUpdateInput.new(
            crop_id: @crop.id,
            stage_id: crop_stage.id,
            payload: { base_temperature: 10.0, optimal_min: 15.0 }
          )

          result = @gateway.create_temperature_requirement(crop_stage.id, dto)

          assert_equal crop_stage.id, result.crop_stage_id
          assert_equal 10.0, result.base_temperature
          assert_equal 15.0, result.optimal_min
        end

        test "update_temperature_requirement updates existing requirement" do
          crop_stage = create(:crop_stage, crop: @crop)
          requirement = create(:temperature_requirement, crop_stage: crop_stage)
          dto = Domain::Crop::Dtos::TemperatureRequirementUpdateInput.new(
            crop_id: @crop.id,
            stage_id: crop_stage.id,
            payload: { base_temperature: 12.0, optimal_max: 25.0 }
          )

          result = @gateway.update_temperature_requirement(crop_stage.id, dto)

          assert_equal 12.0, result.base_temperature
          assert_equal 25.0, result.optimal_max
        end

        # ThermalRequirement tests
        test "thermal find_by_crop_stage_id returns requirement if exists" do
          crop_stage = create(:crop_stage, crop: @crop)
          requirement = create(:thermal_requirement, crop_stage: crop_stage)

          result = @thermal_requirement_gateway.find_by_crop_stage_id(crop_stage.id)

          assert_equal requirement.id, result.id
          assert_equal requirement.required_gdd, result.required_gdd
        end

        test "create_thermal_requirement creates a new requirement" do
          crop_stage = create(:crop_stage, crop: @crop)
          dto = Domain::Crop::Dtos::ThermalRequirementUpdateInput.new(
            crop_id: @crop.id,
            stage_id: crop_stage.id,
            payload: { required_gdd: 100.0 }
          )

          result = @gateway.create_thermal_requirement(crop_stage.id, dto)

          assert_equal crop_stage.id, result.crop_stage_id
          assert_equal 100.0, result.required_gdd
        end

        test "update_thermal_requirement updates existing requirement" do
          crop_stage = create(:crop_stage, crop: @crop)
          requirement = create(:thermal_requirement, crop_stage: crop_stage)
          dto = Domain::Crop::Dtos::ThermalRequirementUpdateInput.new(
            crop_id: @crop.id,
            stage_id: crop_stage.id,
            payload: { required_gdd: 150.0 }
          )

          result = @gateway.update_thermal_requirement(crop_stage.id, dto)

          assert_equal 150.0, result.required_gdd
        end

        # SunshineRequirement tests
        test "sunshine find_by_crop_stage_id returns requirement if exists" do
          crop_stage = create(:crop_stage, crop: @crop)
          requirement = create(:sunshine_requirement, crop_stage: crop_stage)

          result = @sunshine_requirement_gateway.find_by_crop_stage_id(crop_stage.id)

          assert_equal requirement.id, result.id
          assert_equal requirement.minimum_sunshine_hours, result.minimum_sunshine_hours
        end

        test "create_sunshine_requirement creates a new requirement" do
          crop_stage = create(:crop_stage, crop: @crop)
          dto = Domain::Crop::Dtos::SunshineRequirementUpdateInput.new(
            crop_id: @crop.id,
            stage_id: crop_stage.id,
            payload: { minimum_sunshine_hours: 8.0, target_sunshine_hours: 10.0 }
          )

          result = @gateway.create_sunshine_requirement(crop_stage.id, dto)

          assert_equal crop_stage.id, result.crop_stage_id
          assert_equal 8.0, result.minimum_sunshine_hours
          assert_equal 10.0, result.target_sunshine_hours
        end

        test "update_sunshine_requirement updates existing requirement" do
          crop_stage = create(:crop_stage, crop: @crop)
          requirement = create(:sunshine_requirement, crop_stage: crop_stage)
          dto = Domain::Crop::Dtos::SunshineRequirementUpdateInput.new(
            crop_id: @crop.id,
            stage_id: crop_stage.id,
            payload: { target_sunshine_hours: 12.0 }
          )

          result = @gateway.update_sunshine_requirement(crop_stage.id, dto)

          assert_equal 12.0, result.target_sunshine_hours
        end

        # NutrientRequirement tests
        test "nutrient find_by_crop_stage_id returns requirement if exists" do
          crop_stage = create(:crop_stage, crop: @crop)
          requirement = create(:nutrient_requirement, crop_stage: crop_stage)

          result = @nutrient_requirement_gateway.find_by_crop_stage_id(crop_stage.id)

          assert_equal requirement.id, result.id
          assert_equal requirement.daily_uptake_n, result.daily_uptake_n
        end

        test "create_nutrient_requirement creates a new requirement" do
          crop_stage = create(:crop_stage, crop: @crop)
          dto = Domain::Crop::Dtos::NutrientRequirementUpdateInput.new(
            crop_id: @crop.id,
            stage_id: crop_stage.id,
            payload: { daily_uptake_n: 1.5, daily_uptake_p: 0.8, region: "test_region" }
          )

          result = @gateway.create_nutrient_requirement(crop_stage.id, dto)

          assert_equal crop_stage.id, result.crop_stage_id
          assert_equal 1.5, result.daily_uptake_n
          assert_equal 0.8, result.daily_uptake_p
          assert_equal "test_region", result.region
        end

        test "update_nutrient_requirement updates existing requirement" do
          crop_stage = create(:crop_stage, crop: @crop)
          requirement = create(:nutrient_requirement, crop_stage: crop_stage)
          dto = Domain::Crop::Dtos::NutrientRequirementUpdateInput.new(
            crop_id: @crop.id,
            stage_id: crop_stage.id,
            payload: { daily_uptake_k: 2.0, region: "updated_region" }
          )

          result = @gateway.update_nutrient_requirement(crop_stage.id, dto)

          assert_equal 2.0, result.daily_uptake_k
          assert_equal "updated_region", result.region
        end

        test "delete_temperature_requirement deletes existing requirement" do
          crop_stage = create(:crop_stage, crop: @crop)
          create(:temperature_requirement, crop_stage: crop_stage)

          assert_difference("TemperatureRequirement.count", -1) do
            @gateway.delete_temperature_requirement(crop_stage.id)
          end
        end

        test "delete_thermal_requirement deletes existing requirement" do
          crop_stage = create(:crop_stage, crop: @crop)
          create(:thermal_requirement, crop_stage: crop_stage)

          assert_difference("ThermalRequirement.count", -1) do
            @gateway.delete_thermal_requirement(crop_stage.id)
          end
        end

        test "delete_sunshine_requirement deletes existing requirement" do
          crop_stage = create(:crop_stage, crop: @crop)
          create(:sunshine_requirement, crop_stage: crop_stage)

          assert_difference("SunshineRequirement.count", -1) do
            @gateway.delete_sunshine_requirement(crop_stage.id)
          end
        end

        test "delete_nutrient_requirement deletes existing requirement" do
          crop_stage = create(:crop_stage, crop: @crop)
          create(:nutrient_requirement, crop_stage: crop_stage)

          assert_difference("NutrientRequirement.count", -1) do
            @gateway.delete_nutrient_requirement(crop_stage.id)
          end
        end

        test "create_masters_crop_task_template_association creates association with overrides" do
          user = @crop.user
          task = create(:agricultural_task, :user_owned, user: user, name: "元のタスク名")
          input_dto = Domain::Crop::Dtos::MastersCropTaskTemplateCreateInput.new(
            user_id: user.id,
            crop_id: @crop.id,
            agricultural_task_id: task.id,
            name: "カスタム名",
            description: "カスタム説明",
            time_per_sqm: 0.5,
            weather_dependency: "high",
            required_tools: [ "鍬" ],
            skill_level: "advanced"
          )
          result = nil

          assert_difference("CropTaskTemplate.count", 1) do
            result = @gateway.create_masters_crop_task_template_association(input_dto)
          end

          assert result.success?
          template = result.template
          assert_equal @crop.id, template.crop_id
          assert_equal task.id, template.agricultural_task_id
          assert_equal "カスタム名", template.name
          assert_equal "カスタム説明", template.description
          assert_equal 0.5, template.time_per_sqm
          assert_equal "high", template.weather_dependency
          assert_equal [ "鍬" ], template.required_tools
          assert_equal "advanced", template.skill_level
          assert_equal task.id, template.agricultural_task.id
        end

        test "create_masters_crop_task_template_association returns failure when task not found" do
          user = @crop.user
          input_dto = Domain::Crop::Dtos::MastersCropTaskTemplateCreateInput.new(
            user_id: user.id,
            crop_id: @crop.id,
            agricultural_task_id: 99_999
          )

          result = @gateway.create_masters_crop_task_template_association(input_dto)

          assert result.failure?
          assert_equal :agricultural_task_not_found, result.failure.reason
        end

        test "create_masters_crop_task_template_association persists when task belongs to other user (auth is interactor responsibility)" do
          other_user = create(:user)
          user = @crop.user
          task = create(:agricultural_task, :user_owned, user: other_user)
          input_dto = Domain::Crop::Dtos::MastersCropTaskTemplateCreateInput.new(
            user_id: user.id,
            crop_id: @crop.id,
            agricultural_task_id: task.id
          )

          assert_difference("CropTaskTemplate.count", 1) do
            result = @gateway.create_masters_crop_task_template_association(input_dto)
            assert result.template
          end
        end

        test "create_masters_crop_task_template_association returns duplicate when association exists" do
          user = @crop.user
          task = create(:agricultural_task, :user_owned, user: user)
          create(:crop_task_template, crop: @crop, agricultural_task: task)
          input_dto = Domain::Crop::Dtos::MastersCropTaskTemplateCreateInput.new(
            user_id: user.id,
            crop_id: @crop.id,
            agricultural_task_id: task.id
          )

          assert_no_difference("CropTaskTemplate.count") do
            result = @gateway.create_masters_crop_task_template_association(input_dto)
            assert result.failure?
            assert_equal :duplicate, result.failure.reason
          end
        end

        test "create_masters_crop_task_template_association raises record invalid when validation fails" do
          user = @crop.user
          task = create(:agricultural_task, :user_owned, user: user)
          input_dto = Domain::Crop::Dtos::MastersCropTaskTemplateCreateInput.new(
            user_id: user.id,
            crop_id: @crop.id,
            agricultural_task_id: task.id,
            name: ""
          )

          error = assert_raises(Domain::Shared::Exceptions::RecordInvalid) do
            @gateway.create_masters_crop_task_template_association(input_dto)
          end

          assert error.errors.any?, "expected validation error messages"
          assert(
            error.errors.any? { |msg| msg.include?("Name") },
            "expected name validation message, got: #{error.errors.inspect}"
          )
        end

        test "selectable_agricultural_task_picklist_rows_for_nested_templates returns rows excluding already-linked tasks" do
          user = @crop.user
          task_linked = create(:agricultural_task, :user_owned, user: user, name: "LinkedPicklist")
          task_free = create(:agricultural_task, :user_owned, user: user, name: "FreePicklist")
          create(:crop_task_template, crop: @crop, agricultural_task: task_linked)

          rows = @gateway.selectable_agricultural_task_picklist_rows_for_nested_templates(
            user: user,
            crop_id: @crop.id,
          )

          ids = rows.map { |r| r[:id] }
          refute_includes ids, task_linked.id
          assert_includes ids, task_free.id
          hit = rows.find { |r| r[:id] == task_free.id }
          assert_equal task_free.id, hit[:id]
          assert_equal task_free.name, hit[:name]
        end

        test "selectable_agricultural_task_picklist_rows_for_nested_templates resolves crop by id without user scope" do
          other_crop = create(:crop, :user_owned, user: create(:user))
          user = @crop.user
          task_free = create(:agricultural_task, :user_owned, user: user)

          rows = @gateway.selectable_agricultural_task_picklist_rows_for_nested_templates(
            user: user,
            crop_id: other_crop.id,
          )

          assert_includes rows.map { |r| r[:id] }, task_free.id
        end

        test "list_index_for_filter owned_non_reference returns only that user's non-reference crops" do
          user = create(:user)
          other = create(:user)
          owned = create(:crop, :user_owned, user: user)
          create(:crop, :reference)
          create(:crop, :user_owned, user: other)

          filter = Domain::Shared::ValueObjects::ReferenceIndexListFilter.new(mode: :owned_non_reference, user_id: user.id)
          ids = @gateway.list_index_for_filter(filter).map(&:id)

          assert_equal [ owned.id ], ids
        end

        test "list_index_for_filter reference_or_owned returns reference rows and rows owned by user_id" do
          admin = create(:user, admin: true)
          ref = create(:crop, :reference)
          own = create(:crop, :user_owned, user: admin)
          other = create(:user)
          other_crop = create(:crop, :user_owned, user: other)

          filter = Domain::Shared::ValueObjects::ReferenceIndexListFilter.new(mode: :reference_or_owned, user_id: admin.id)
          ids = @gateway.list_index_for_filter(filter).map(&:id)

          assert_includes ids, ref.id
          assert_includes ids, own.id
          assert_not_includes ids, other_crop.id
        end
      end
    end
  end
end
