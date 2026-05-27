# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module CultivationPlan
    module Interactors
      class CropTaskScheduleBlueprintCopyInteractorTest < DomainLibTestCase
        def blueprint_row(task_id: 10, source_task_id: 10)
          Dtos::CropTaskScheduleBlueprintRow.new(
            agricultural_task_id: task_id,
            source_agricultural_task_id: source_task_id,
            stage_order: 0,
            stage_name: "苗",
            gdd_trigger: 5.0,
            gdd_tolerance: 1.0,
            task_type: "field_work",
            source: "agrr",
            priority: 1,
            amount: nil,
            amount_unit: nil,
            description: nil,
            weather_dependency: nil,
            time_per_sqm: 1.0
          )
        end

        def build_interactor(blueprint_gateway:, task_mapping_port:)
          CropTaskScheduleBlueprintCopyInteractor.new(
            blueprint_gateway: blueprint_gateway,
            task_mapping_port: task_mapping_port,
            logger: CapturingLogger.new
          )
        end

        test "maps reference task id and replaces user crop blueprints" do
          blueprint_gateway = mock("blueprint_gateway")
          blueprint_gateway.expects(:list_by_crop_id).with(crop_id: 1).returns([ blueprint_row ])
          blueprint_gateway.expects(:delete_by_crop_id).with(crop_id: 99)
          blueprint_gateway.expects(:bulk_create).with do |records:|
            assert_equal 1, records.size
            assert_equal 99, records.first.crop_id
            assert_equal 20, records.first.agricultural_task_id
            assert_equal 10, records.first.source_agricultural_task_id
            true
          end

          task_mapping_port = mock("task_mapping_port")
          task_mapping_port.expects(:user_task_id_for).with(reference_task_id: 10).returns(20)

          build_interactor(
            blueprint_gateway: blueprint_gateway,
            task_mapping_port: task_mapping_port
          ).call(
            Dtos::CropTaskScheduleBlueprintCopyInput.new(
              reference_crop_id_to_user_crop_id: { 1 => 99 }
            )
          )
        end

        test "second call is idempotent via delete then bulk_create" do
          blueprint_gateway = mock("blueprint_gateway")
          blueprint_gateway.expects(:list_by_crop_id).twice.with(crop_id: 1).returns([ blueprint_row ])
          blueprint_gateway.expects(:delete_by_crop_id).twice.with(crop_id: 99)
          blueprint_gateway.expects(:bulk_create).twice

          task_mapping_port = mock("task_mapping_port")
          task_mapping_port.expects(:user_task_id_for).twice.with(reference_task_id: 10).returns(20)

          interactor = build_interactor(
            blueprint_gateway: blueprint_gateway,
            task_mapping_port: task_mapping_port
          )
          input = Dtos::CropTaskScheduleBlueprintCopyInput.new(
            reference_crop_id_to_user_crop_id: { 1 => 99 }
          )

          interactor.call(input)
          interactor.call(input)
        end

        test "no-op when mapping is blank" do
          blueprint_gateway = mock("blueprint_gateway")
          blueprint_gateway.expects(:list_by_crop_id).never

          build_interactor(
            blueprint_gateway: blueprint_gateway,
            task_mapping_port: mock("task_mapping_port")
          ).call(
            Dtos::CropTaskScheduleBlueprintCopyInput.new(
              reference_crop_id_to_user_crop_id: {}
            )
          )
        end
      end
    end
  end
end
