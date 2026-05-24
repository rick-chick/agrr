# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module CultivationPlan
    module Interactors
      class AdvanceCultivationPlanPhaseInteractorTest < DomainLibTestCase
        setup do
          @plan_entity = Entities::CultivationPlanEntity.new(
            id: 1,
            farm_id: 1,
            user_id: 1,
            total_area: 100.0,
            plan_type: "public",
            status: "optimizing",
            optimization_phase: "fetching_weather",
            optimization_phase_message: "取得中"
          )
          @field_cultivation = Entities::FieldCultivationEntity.new(
            id: 10,
            cultivation_plan_id: 1,
            cultivation_plan_field_id: 1,
            cultivation_plan_crop_id: 1,
            area: 50.0,
            status: "completed"
          )
          @gateway = mock("cultivation_plan_gateway")
          @translator = mock("translator")
          @broadcast_port = mock("phase_broadcast_port")
          @interactor = AdvanceCultivationPlanPhaseInteractor.new(
            cultivation_plan_gateway: @gateway,
            translator: @translator,
            phase_broadcast_port: @broadcast_port
          )
        end

        test "call updates plan and broadcasts when phase requires broadcast" do
          @translator.expects(:t).with("models.cultivation_plan.phases.fetching_weather").returns("気象取得中")
          @gateway.expects(:update).with(1, has_entries(optimization_phase: "fetching_weather")).returns(@plan_entity)
          @gateway.stubs(:list_by_plan_id).with(1).returns([@field_cultivation])
          @broadcast_port.expects(:broadcast_phase_update).with(
            plan_id: 1,
            channel_class: "TestChannel",
            payload: has_entries(status: "optimizing", progress: 100)
          )
          @gateway.expects(:find_by_id).with(1).returns(@plan_entity)
          @gateway.expects(:update).with(1, { status: "completed" }).returns(@plan_entity)

          @interactor.call(
            Dtos::AdvanceCultivationPlanPhaseInput.new(
              plan_id: 1,
              phase_name: :phase_fetching_weather,
              channel_class: "TestChannel"
            )
          )
        end

        test "call skips broadcast when start_optimizing" do
          @gateway.expects(:update).with(1, { status: "optimizing" }).returns(@plan_entity)
          @broadcast_port.expects(:broadcast_phase_update).never
          @gateway.expects(:find_by_id).with(1).returns(@plan_entity)
          @gateway.expects(:list_by_plan_id).with(1).returns([])

          @interactor.call(
            Dtos::AdvanceCultivationPlanPhaseInput.new(
              plan_id: 1,
              phase_name: :start_optimizing
            )
          )
        end
      end
    end
  end
end
