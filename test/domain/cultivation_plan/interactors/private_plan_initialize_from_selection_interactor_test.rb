# frozen_string_literal: true

require "domain_lib_test_helper"
require "adapters/shared/ports/rails_translator_adapter"
require "logger"

module Domain
  module CultivationPlan
    module Interactors
      class PrivatePlanInitializeFromSelectionInteractorTest < DomainLibTestCase
        # @clock.today = Date.new(2026, 6, 15) => beginning_of_year = Date.new(2026, 1, 1)
        PLANNING_START_DATE = Date.new(2026, 1, 1)
        PLANNING_END_DATE = Date.new(2027, 12, 31)

        setup do
          @user_id = 1
          @user = stub(id: @user_id, admin?: false)
          @farm_entity = Domain::Farm::Entities::FarmEntity.new(
            id: 1,
            name: "F",
            latitude: 35.0,
            longitude: 139.0,
            region: "jp",
            user_id: @user_id,
            created_at: Time.utc(2026, 1, 1),
            updated_at: Time.utc(2026, 1, 1),
            is_reference: false
          )
          @crop_entity = Domain::Crop::Entities::CropEntity.new(
            id: 10,
            user_id: @user_id,
            name: "C",
            variety: "V",
            is_reference: false,
            area_per_unit: 1.0,
            revenue_per_area: 1.0,
            region: "jp",
            groups: [],
            crop_stages: [],
            created_at: Time.utc(2026, 1, 1),
            updated_at: Time.utc(2026, 1, 1)
          )
          @gateway = mock("cultivation_plan_gateway")
          @output_port = mock("output_port")
           @logger = ::Logger.new(File::NULL)
          @translator = Adapters::Shared::Ports::RailsTranslatorAdapter.new
          @clock = Object.new
          def @clock.today
            Date.new(2026, 6, 15)
          end
          @session_gen = -> { "sessionhex" }
          @job_enqueuer = mock("job_enqueuer")
        end

        def interactor
          PrivatePlanInitializeFromSelectionInteractor.new(
            output_port: @output_port,
            cultivation_plan_gateway: @gateway,
            logger: @logger,
            translator: @translator,
            clock: @clock,
            session_id_generator: @session_gen,
            job_chain_enqueuer: @job_enqueuer
          )
        end

        test "on_failure unprocessable when crop_ids empty" do
          dto = Dtos::PrivatePlanInitializeFromSelectionInput.new(farm_id: 1, crop_ids: [], user: @user)
          @output_port.expects(:on_failure).with do |f|
            assert_equal :unprocessable_entity, f.http_status
            assert_equal @translator.t("plans.errors.select_crop"), f.message
            true
          end
          interactor.call(dto)
        end

        test "on_failure not_found when farm missing" do
          dto = Dtos::PrivatePlanInitializeFromSelectionInput.new(farm_id: 99, crop_ids: [ 10 ], user: @user)
          @gateway.expects(:find_by_farm_id).with(99, @user).returns(nil)
          @output_port.expects(:on_failure).with do |f|
            assert_equal :not_found, f.http_status
            true
          end
          interactor.call(dto)
        end

        test "on_failure not_found when no crops resolved" do
          dto = Dtos::PrivatePlanInitializeFromSelectionInput.new(farm_id: 1, crop_ids: [ 10 ], user: @user)
          @gateway.expects(:find_by_farm_id).returns(@farm_entity)
          @gateway.expects(:list_by_ids).returns([])
          @output_port.expects(:on_failure).with do |f|
            assert_equal :not_found, f.http_status
            true
          end
          interactor.call(dto)
        end

        test "on_failure unprocessable when plan exists" do
          dto = Dtos::PrivatePlanInitializeFromSelectionInput.new(farm_id: 1, crop_ids: [ 10 ], user: @user)
          existing = Domain::CultivationPlan::Entities::CultivationPlanEntity.new(
            id: 99, farm_id: 1, user_id: @user_id, total_area: 1.0, plan_type: "private",
            plan_year: nil, plan_name: "x",
            planning_start_date: Date.new(2026, 1, 1), planning_end_date: Date.new(2026, 1, 1),
            status: "draft", session_id: nil, display_name: "x",
            cultivation_plan_crops_count: 0, cultivation_plan_fields_count: 0,
            created_at: Time.utc(2026, 1, 1), updated_at: Time.utc(2026, 1, 1)
          )
          @gateway.expects(:find_by_farm_id).returns(@farm_entity)
          @gateway.expects(:list_by_ids).returns([ @crop_entity ])
          @gateway.expects(:find_existing).returns(existing)
          @output_port.expects(:on_failure).with do |f|
            assert_equal :unprocessable_entity, f.http_status
            true
          end
          interactor.call(dto)
        end

        test "on_success enqueues jobs and returns id" do
          dto = Dtos::PrivatePlanInitializeFromSelectionInput.new(farm_id: 1, crop_ids: [ 10 ], user: @user, plan_name: "P")
          created = Domain::CultivationPlan::Entities::CultivationPlanEntity.new(
            id: 42, farm_id: 1, user_id: @user_id, total_area: 1.0, plan_type: "private",
            plan_year: nil, plan_name: "P",
            planning_start_date: PLANNING_START_DATE,
            planning_end_date: PLANNING_END_DATE,
            status: "draft", session_id: "sessionhex", display_name: "P",
            cultivation_plan_crops_count: 1, cultivation_plan_fields_count: 1,
            created_at: Time.utc(2026, 1, 1), updated_at: Time.utc(2026, 1, 1)
          )
          result = CultivationPlanInitializeInteractor::Result.new(cultivation_plan: created, errors: [])
          @gateway.expects(:find_by_farm_id).returns(@farm_entity)
          @gateway.expects(:list_by_ids).returns([ @crop_entity ])
          @gateway.expects(:find_existing).returns(nil)
          @gateway.expects(:total_field_area_for_farm).with(1, @user).returns(100.0)
          @gateway.expects(:initialize_plan_from_selection).with(
            farm: @farm_entity,
            total_area: 100.0,
            crops: [ @crop_entity ],
            user: @user,
            session_id: "sessionhex",
            plan_type: "private",
            plan_year: nil,
            plan_name: "P",
            planning_start_date: PLANNING_START_DATE,
            planning_end_date: PLANNING_END_DATE
          ).returns(result)

          @job_enqueuer.expects(:enqueue_after_create).with(cultivation_plan_id: 42)
          @output_port.expects(:on_success).with do |s|
            assert_equal 42, s.id
            true
          end
          interactor.call(dto)
        end

        test "on_failure unprocessable when initialize returns errors" do
          dto = Dtos::PrivatePlanInitializeFromSelectionInput.new(farm_id: 1, crop_ids: [ 10 ], user: @user)
          result = CultivationPlanInitializeInteractor::Result.new(cultivation_plan: nil, errors: [ "boom" ])
          @gateway.expects(:find_by_farm_id).returns(@farm_entity)
          @gateway.expects(:list_by_ids).returns([ @crop_entity ])
          @gateway.expects(:find_existing).returns(nil)
          @gateway.expects(:total_field_area_for_farm).returns(10.0)
          @gateway.expects(:initialize_plan_from_selection).returns(result)
          @job_enqueuer.expects(:enqueue_after_create).never
          @output_port.expects(:on_failure).with do |f|
            assert_equal :unprocessable_entity, f.http_status
            assert_equal "boom", f.message
            true
          end
          interactor.call(dto)
        end

        test "enqueue_after_create raises StandardError propagates" do
          dto = Dtos::PrivatePlanInitializeFromSelectionInput.new(farm_id: 1, crop_ids: [ 10 ], user: @user)
          created = Domain::CultivationPlan::Entities::CultivationPlanEntity.new(
            id: 42, farm_id: 1, user_id: @user_id, total_area: 1.0, plan_type: "private",
            plan_year: nil, plan_name: "P",
            planning_start_date: PLANNING_START_DATE,
            planning_end_date: PLANNING_END_DATE,
            status: "draft", session_id: "sessionhex", display_name: "P",
            cultivation_plan_crops_count: 1, cultivation_plan_fields_count: 1,
            created_at: Time.utc(2026, 1, 1), updated_at: Time.utc(2026, 1, 1)
          )
          result = CultivationPlanInitializeInteractor::Result.new(cultivation_plan: created, errors: [])
          @gateway.expects(:find_by_farm_id).returns(@farm_entity)
          @gateway.expects(:list_by_ids).returns([ @crop_entity ])
          @gateway.expects(:find_existing).returns(nil)
          @gateway.expects(:total_field_area_for_farm).returns(10.0)
          @gateway.expects(:initialize_plan_from_selection).returns(result)
          @job_enqueuer.expects(:enqueue_after_create).raises(StandardError, "queue down")
          @output_port.expects(:on_success).never
          @output_port.expects(:on_failure).never

          err = assert_raises(StandardError) do
            interactor.call(dto)
          end
          assert_equal "queue down", err.message
        end
      end
    end
  end
end
