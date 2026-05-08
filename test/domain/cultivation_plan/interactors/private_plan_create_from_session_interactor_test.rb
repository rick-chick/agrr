# frozen_string_literal: true

require "test_helper"

module Domain
  module CultivationPlan
    module Interactors
      class PrivatePlanCreateFromSessionInteractorTest < ActiveSupport::TestCase
        setup do
          @user = create(:user)
          @farm_entity = Domain::Farm::Entities::FarmEntity.new(
            id: 1,
            name: "F",
            latitude: 35.0,
            longitude: 139.0,
            region: "jp",
            user_id: @user.id,
            created_at: Time.current,
            updated_at: Time.current,
            is_reference: false
          )
          @crop_entity = Domain::Crop::Entities::CropEntity.new(
            id: 10,
            user_id: @user.id,
            name: "C",
            variety: "V",
            is_reference: false,
            area_per_unit: 1.0,
            revenue_per_area: 1.0,
            region: "jp",
            groups: [],
            crop_stages: [],
            created_at: Time.current,
            updated_at: Time.current
          )
          @gateway = mock("cultivation_plan_gateway")
          @output_port = mock("output_port")
          @logger = Adapters::Logger::Gateways::RailsLoggerGateway.new
          @translator = Adapters::Translators::RailsTranslator.new
          @clock = Object.new
          def @clock.today
            Date.new(2026, 6, 15)
          end
          @session_gen = -> { "sess-html" }
          @post_create_job_chain = mock("post_create_job_chain")
          @select_crop_runner = mock("select_crop_context_runner")
        end

        def interactor
          PrivatePlanCreateFromSessionInteractor.new(
            output_port: @output_port,
            cultivation_plan_gateway: @gateway,
            logger: @logger,
            translator: @translator,
            clock: @clock,
            session_id_generator: @session_gen,
            post_create_job_chain: @post_create_job_chain,
            select_crop_context_runner: @select_crop_runner
          )
        end

        test "on_missing_session when farm_id blank" do
          dto = Domain::CultivationPlan::Dtos::PrivatePlanCreateFromSessionInputDto.new(
            farm_id: nil,
            crop_ids: [ 10 ],
            user: @user
          )
          @output_port.expects(:on_missing_session)
          interactor.call(dto)
        end

        test "on_restart when farm missing" do
          dto = Domain::CultivationPlan::Dtos::PrivatePlanCreateFromSessionInputDto.new(
            farm_id: 1,
            crop_ids: [ 10 ],
            user: @user
          )
          @gateway.expects(:find_farm).with(1, @user).returns(nil)
          @output_port.expects(:on_restart)
          interactor.call(dto)
        end

        test "on_no_crops_selected when crop_ids empty" do
          dto = Domain::CultivationPlan::Dtos::PrivatePlanCreateFromSessionInputDto.new(
            farm_id: 1,
            crop_ids: [],
            user: @user
          )
          @gateway.expects(:find_farm).returns(@farm_entity)
          @select_crop_runner.expects(:call).with(farm_id: 1)
          @select_crop_runner.expects(:response_committed?).returns(false)
          @output_port.expects(:on_no_crops_selected)
          interactor.call(dto)
        end

        test "on_no_crops_selected when crops not resolved" do
          dto = Domain::CultivationPlan::Dtos::PrivatePlanCreateFromSessionInputDto.new(
            farm_id: 1,
            crop_ids: [ 99 ],
            user: @user
          )
          @gateway.expects(:find_farm).returns(@farm_entity)
          @gateway.expects(:find_crops).returns([])
          @select_crop_runner.expects(:call).with(farm_id: 1)
          @select_crop_runner.expects(:response_committed?).returns(false)
          @output_port.expects(:on_no_crops_selected)
          interactor.call(dto)
        end

        test "on_existing_plan when plan exists" do
          dto = Domain::CultivationPlan::Dtos::PrivatePlanCreateFromSessionInputDto.new(
            farm_id: 1,
            crop_ids: [ 10 ],
            user: @user
          )
          existing = Domain::CultivationPlan::Entities::CultivationPlanEntity.new(
            id: 88,
            farm_id: 1,
            user_id: @user.id,
            total_area: 1.0,
            plan_type: "private",
            plan_year: 2024,
            plan_name: "x",
            planning_start_date: Date.current,
            planning_end_date: Date.current,
            status: "draft",
            session_id: nil,
            display_name: "x",
            cultivation_plan_crops_count: 0,
            cultivation_plan_fields_count: 0,
            created_at: Time.current,
            updated_at: Time.current
          )
          @gateway.expects(:find_farm).returns(@farm_entity)
          @gateway.expects(:find_crops).returns([ @crop_entity ])
          @gateway.expects(:find_existing).returns(existing)
          @output_port.expects(:on_existing_plan).with(plan_id: 88, plan_year: 2024)
          interactor.call(dto)
        end

        test "on_success enqueues post-create job chain then notifies presenter" do
          dto = Domain::CultivationPlan::Dtos::PrivatePlanCreateFromSessionInputDto.new(
            farm_id: 1,
            crop_ids: [ 10 ],
            user: @user,
            plan_name: "P",
            total_area: 50.0
          )
          created = Domain::CultivationPlan::Entities::CultivationPlanEntity.new(
            id: 42,
            farm_id: 1,
            user_id: @user.id,
            total_area: 50.0,
            plan_type: "private",
            plan_year: nil,
            plan_name: "P",
            planning_start_date: @clock.today.beginning_of_year,
            planning_end_date: Date.new(@clock.today.year + 1, 12, 31),
            status: "draft",
            session_id: "sess-html",
            display_name: "P",
            cultivation_plan_crops_count: 1,
            cultivation_plan_fields_count: 1,
            created_at: Time.current,
            updated_at: Time.current
          )
          result = CultivationPlanInitializeInteractor::Result.new(cultivation_plan: created, errors: [])
          @gateway.expects(:find_farm).returns(@farm_entity)
          @gateway.expects(:find_crops).returns([ @crop_entity ])
          @gateway.expects(:find_existing).returns(nil)
          @gateway.expects(:initialize_plan_from_selection).with(
            farm: @farm_entity,
            total_area: 50.0,
            crops: [ @crop_entity ],
            user: @user,
            session_id: "sess-html",
            plan_type: "private",
            plan_year: nil,
            plan_name: "P",
            planning_start_date: @clock.today.beginning_of_year,
            planning_end_date: Date.new(@clock.today.year + 1, 12, 31)
          ).returns(result)

          @post_create_job_chain.expects(:enqueue_for_plan).with(plan_id: 42)
          @output_port.expects(:on_success).with(plan_id: 42)
          interactor.call(dto)
        end

        test "total_area from gateway when omitted in dto" do
          dto = Domain::CultivationPlan::Dtos::PrivatePlanCreateFromSessionInputDto.new(
            farm_id: 1,
            crop_ids: [ 10 ],
            user: @user,
            plan_name: nil,
            total_area: nil
          )
          created = Domain::CultivationPlan::Entities::CultivationPlanEntity.new(
            id: 42,
            farm_id: 1,
            user_id: @user.id,
            total_area: 120.0,
            plan_type: "private",
            plan_year: nil,
            plan_name: "F",
            planning_start_date: @clock.today.beginning_of_year,
            planning_end_date: Date.new(@clock.today.year + 1, 12, 31),
            status: "draft",
            session_id: "sess-html",
            display_name: "F",
            cultivation_plan_crops_count: 1,
            cultivation_plan_fields_count: 1,
            created_at: Time.current,
            updated_at: Time.current
          )
          result = CultivationPlanInitializeInteractor::Result.new(cultivation_plan: created, errors: [])
          @gateway.expects(:find_farm).returns(@farm_entity)
          @gateway.expects(:find_crops).returns([ @crop_entity ])
          @gateway.expects(:find_existing).returns(nil)
          @gateway.expects(:total_field_area_for_farm).with(1, @user).returns(120.0)
          @gateway.expects(:initialize_plan_from_selection).with(
            farm: @farm_entity,
            total_area: 120.0,
            crops: [ @crop_entity ],
            user: @user,
            session_id: "sess-html",
            plan_type: "private",
            plan_year: nil,
            plan_name: "F",
            planning_start_date: @clock.today.beginning_of_year,
            planning_end_date: Date.new(@clock.today.year + 1, 12, 31)
          ).returns(result)

          @post_create_job_chain.expects(:enqueue_for_plan).with(plan_id: 42)
          @output_port.expects(:on_success).with(plan_id: 42)
          interactor.call(dto)
        end

        test "on_initialize_failed when initialize returns errors" do
          dto = Domain::CultivationPlan::Dtos::PrivatePlanCreateFromSessionInputDto.new(
            farm_id: 1,
            crop_ids: [ 10 ],
            user: @user
          )
          result = CultivationPlanInitializeInteractor::Result.new(cultivation_plan: nil, errors: [ "boom" ])
          @gateway.expects(:find_farm).returns(@farm_entity)
          @gateway.expects(:find_crops).returns([ @crop_entity ])
          @gateway.expects(:find_existing).returns(nil)
          @gateway.expects(:total_field_area_for_farm).returns(10.0)
          @gateway.expects(:initialize_plan_from_selection).returns(result)

          @output_port.expects(:on_initialize_failed).with(message: "boom")
          interactor.call(dto)
        end
      end
    end
  end
end
