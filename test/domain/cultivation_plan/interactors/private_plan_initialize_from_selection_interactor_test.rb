# frozen_string_literal: true

require "domain_lib_test_helper"
require "logger"

module Domain
  module CultivationPlan
    module Interactors
      class PrivatePlanInitializeFromSelectionInteractorTest < DomainLibTestCase
        FakeTranslator = Struct.new do
          def t(key)
            key.to_s
          end
        end
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
          @farm_gateway = mock("farm_gateway")
          @crop_gateway = mock("crop_gateway")
          @field_gateway = mock("field_gateway")
          @plan_initializer = mock("plan_initializer")
          @output_port = mock("output_port")
          @logger = ::Logger.new(File::NULL)
          @translator = FakeTranslator.new
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
            farm_gateway: @farm_gateway,
            crop_gateway: @crop_gateway,
            field_gateway: @field_gateway,
            plan_initializer: @plan_initializer,
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
          @farm_gateway.expects(:find_by_id).with(99).raises(Domain::Shared::Exceptions::RecordNotFound)
          @output_port.expects(:on_failure).with do |f|
            assert_equal :not_found, f.http_status
            true
          end
          interactor.call(dto)
        end

        test "on_failure not_found when farm is not visible to user" do
          dto = Dtos::PrivatePlanInitializeFromSelectionInput.new(farm_id: 2, crop_ids: [ 10 ], user: @user)
          other_farm = Domain::Farm::Entities::FarmEntity.new(
            id: 2,
            name: "Other",
            latitude: 35.0,
            longitude: 139.0,
            region: "jp",
            user_id: 99,
            created_at: Time.utc(2026, 1, 1),
            updated_at: Time.utc(2026, 1, 1),
            is_reference: false
          )
          @farm_gateway.expects(:find_by_id).with(2).returns(other_farm)
          @crop_gateway.expects(:list_by_ids).never
          @output_port.expects(:on_failure).with do |f|
            assert_equal :not_found, f.http_status
            true
          end
          interactor.call(dto)
        end

        test "on_failure not_found when no crops resolved" do
          dto = Dtos::PrivatePlanInitializeFromSelectionInput.new(farm_id: 1, crop_ids: [ 10 ], user: @user)
          @farm_gateway.expects(:find_by_id).with(1).returns(@farm_entity)
          @crop_gateway.expects(:list_by_ids).with([ 10 ]).returns([])
          @output_port.expects(:on_failure).with do |f|
            assert_equal :not_found, f.http_status
            true
          end
          interactor.call(dto)
        end

        test "on_failure not_found when crop not editable by user" do
          dto = Dtos::PrivatePlanInitializeFromSelectionInput.new(farm_id: 1, crop_ids: [ 10 ], user: @user)
          ref_crop = Domain::Crop::Entities::CropEntity.new(
            id: 10,
            user_id: nil,
            name: "R",
            variety: "V",
            is_reference: true,
            area_per_unit: 1.0,
            revenue_per_area: 1.0,
            region: "jp",
            groups: [],
            crop_stages: [],
            created_at: Time.utc(2026, 1, 1),
            updated_at: Time.utc(2026, 1, 1)
          )
          @farm_gateway.expects(:find_by_id).with(1).returns(@farm_entity)
          @crop_gateway.expects(:list_by_ids).with([ 10 ]).returns([ ref_crop ])
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
          @farm_gateway.expects(:find_by_id).returns(@farm_entity)
          @crop_gateway.expects(:list_by_ids).returns([ @crop_entity ])
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
          @farm_gateway.expects(:find_by_id).returns(@farm_entity)
          @crop_gateway.expects(:list_by_ids).returns([ @crop_entity ])
          @gateway.expects(:find_existing).returns(nil)
          @field_gateway.expects(:get_total_area_by_farm_id).with(farm_id: 1).returns(100.0)
          @plan_initializer.expects(:call).with(
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
          @farm_gateway.expects(:find_by_id).returns(@farm_entity)
          @crop_gateway.expects(:list_by_ids).returns([ @crop_entity ])
          @gateway.expects(:find_existing).returns(nil)
          @field_gateway.expects(:get_total_area_by_farm_id).with(farm_id: 1).returns(10.0)
          @plan_initializer.expects(:call).returns(result)
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
          @farm_gateway.expects(:find_by_id).returns(@farm_entity)
          @crop_gateway.expects(:list_by_ids).returns([ @crop_entity ])
          @gateway.expects(:find_existing).returns(nil)
          @field_gateway.expects(:get_total_area_by_farm_id).with(farm_id: 1).returns(10.0)
          @plan_initializer.expects(:call).returns(result)
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
