# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module CultivationPlan
    module Interactors
      class TaskScheduleTimelineInteractorTest < DomainLibTestCase
        class StubOutputPort < Domain::CultivationPlan::Ports::TaskScheduleTimelineOutputPort
          attr_reader :success_dto, :failure_dto

          def on_success(dto)
            @success_dto = dto
          end

          def on_failure(error_dto)
            @failure_dto = error_dto
          end
        end

        ReadModel = Struct.new(:plan, :fields, :scheduled_dates, keyword_init: true)
        PlanRef = Struct.new(:id, keyword_init: true)
        FieldRow = Struct.new(:field_cultivation_id, :task_options, keyword_init: true)
        TaskOption = Struct.new(:template_id, keyword_init: true)

        class FakePrivateReadGateway
          attr_reader :received_plan_id

          def initialize(read_model)
            @read_model = read_model
          end

          def find_task_schedule_timeline_by_plan_id(plan_id:)
            @received_plan_id = plan_id
            @read_model
          end
        end

        class FakeCultivationPlanGateway
          def initialize(plan_entity)
            @plan_entity = plan_entity
          end

          def find_by_id(_plan_id)
            @plan_entity
          end
        end

        class FakeUserLookup
          def initialize(user: nil, raise_not_found: false)
            @user = user
            @raise_not_found = raise_not_found
          end

          def find(_user_id)
            raise Domain::Shared::Exceptions::RecordNotFound if @raise_not_found

            @user
          end
        end

        class RecordingLogger
          attr_reader :warns, :errors

          def initialize
            @warns = []
            @errors = []
          end

          def warn(message)
            @warns << message
          end

          def error(message)
            @errors << message
          end
        end

        class StubTranslator
          def t(key, **_options)
            "t:#{key}"
          end
        end

        setup do
          @plan_id = 99
          @user_id = 1
          @today = Date.new(2025, 1, 10)
          @clock = Struct.new(:today).new(@today)
          @output_port = StubOutputPort.new
          @logger = RecordingLogger.new
          @translator = StubTranslator.new
          @plan_entity = Domain::CultivationPlan::Entities::CultivationPlanEntity.new(
            id: @plan_id,
            farm_id: 1,
            user_id: @user_id,
            total_area: 1,
            plan_type: "private"
          )
        end

        test "loads timeline snapshot and passes the assembled dto to on_success" do
          read_model = ReadModel.new(
            plan: PlanRef.new(id: @plan_id),
            fields: [ FieldRow.new(field_cultivation_id: 7, task_options: [ TaskOption.new(template_id: 31) ]) ],
            scheduled_dates: [ Date.new(2025, 1, 10) ]
          )
          private_read_gateway = FakePrivateReadGateway.new(read_model)

          build_interactor(
            private_read_gateway: private_read_gateway,
            user_lookup: FakeUserLookup.new(user: Struct.new(:id).new(@user_id))
          ).call

          assert_nil @output_port.failure_dto
          dto = @output_port.success_dto
          assert_not_nil dto
          assert_equal @plan_id, dto.plan.id
          assert_equal @today, dto.today
          assert_equal 1, dto.fields.size
          assert_equal 7, dto.fields.first.field_cultivation_id
          assert_equal 31, dto.fields.first.task_options.first.template_id
          assert_includes dto.scheduled_dates, Date.new(2025, 1, 10)
        end

        test "passes plan_id to the private read gateway" do
          read_model = ReadModel.new(plan: PlanRef.new(id: @plan_id), fields: [], scheduled_dates: [])
          private_read_gateway = FakePrivateReadGateway.new(read_model)

          build_interactor(
            private_read_gateway: private_read_gateway,
            user_lookup: FakeUserLookup.new(user: Struct.new(:id).new(@user_id))
          ).call

          assert_equal @plan_id, private_read_gateway.received_plan_id
        end

        test "calls on_failure when the user cannot be resolved" do
          private_read_gateway = FakePrivateReadGateway.new(
            ReadModel.new(plan: nil, fields: [], scheduled_dates: [])
          )

          build_interactor(
            private_read_gateway: private_read_gateway,
            user_lookup: FakeUserLookup.new(raise_not_found: true)
          ).call

          assert_nil @output_port.success_dto
          assert_instance_of Domain::Shared::Dtos::Error, @output_port.failure_dto
          assert_equal "t:plans.errors.session_invalid", @output_port.failure_dto.message
          refute_empty @logger.warns
        end

        test "calls on_failure when private plan access is denied" do
          read_model = ReadModel.new(plan: PlanRef.new(id: @plan_id), fields: [], scheduled_dates: [])
          private_read_gateway = FakePrivateReadGateway.new(read_model)
          other_user_plan = Domain::CultivationPlan::Entities::CultivationPlanEntity.new(
            id: @plan_id,
            farm_id: 1,
            user_id: 999,
            total_area: 1,
            plan_type: "private"
          )

          build_interactor(
            private_read_gateway: private_read_gateway,
            cultivation_plan_gateway: FakeCultivationPlanGateway.new(other_user_plan),
            user_lookup: FakeUserLookup.new(user: Struct.new(:id).new(@user_id))
          ).call

          assert_nil @output_port.success_dto
          assert_equal "t:plans.errors.not_found", @output_port.failure_dto.message
          assert_nil private_read_gateway.received_plan_id,
            "timeline read gateway must not run when access is denied"
        end

        private

        def build_interactor(private_read_gateway:, user_lookup:, cultivation_plan_gateway: nil)
          TaskScheduleTimelineInteractor.new(
            output_port: @output_port,
            user_id: @user_id,
            plan_id: @plan_id,
            private_read_gateway: private_read_gateway,
            cultivation_plan_gateway: cultivation_plan_gateway || FakeCultivationPlanGateway.new(@plan_entity),
            translator: @translator,
            logger: @logger,
            user_lookup: user_lookup,
            clock: @clock
          )
        end
      end
    end
  end
end
