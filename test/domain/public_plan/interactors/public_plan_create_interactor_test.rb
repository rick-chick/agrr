# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module PublicPlan
    module Interactors
      # PublicPlanCreateInteractor の純粋ユニットテスト（memory gateway 注入・Rails 非依存）。
      # 旧 test/integration/domain/... を ARCHITECTURE.md Testing 規約に沿って書き直したもの。
      class PublicPlanCreateInteractorTest < DomainLibTestCase
        Farm = Struct.new(:id, :name, :region, keyword_init: true)
        Crop = Struct.new(:id, :name, keyword_init: true)
        PlanRef = Struct.new(:id, keyword_init: true)

        FIXED_CLOCK = Struct.new(:today).new(Date.new(2025, 4, 1))

        class FakePublicPlanGateway
          def initialize(farm: nil, farm_size: nil, crops: [], farm_size_error: nil)
            @farm = farm
            @farm_size = farm_size
            @crops = crops
            @farm_size_error = farm_size_error
          end

          def find_farm(_farm_id)
            @farm
          end

          def find_farm_size(_farm_size_id)
            raise @farm_size_error if @farm_size_error

            @farm_size
          end

          def find_crops(_crop_ids, _region)
            @crops
          end
        end

        class RecordingOutputPort
          attr_reader :success, :failure, :events

          def initialize
            @events = []
          end

          def on_success(dto)
            @success = dto
            @events << :success
          end

          def on_failure(error)
            @failure = error
            @events << :failure
          end
        end

        class FakeJobChain
          attr_reader :calls

          def initialize(events)
            @events = events
            @calls = []
          end

          def enqueue_after_create!(cultivation_plan_id:, caller_label:, redirect_path: nil)
            @calls << { cultivation_plan_id: cultivation_plan_id, caller_label: caller_label, redirect_path: redirect_path }
            @events << :enqueue
          end
        end

        setup do
          @output_port = RecordingOutputPort.new
          @logger = CapturingLogger.new
        end

        test "initialize requires a clock responding to :today" do
          error = assert_raises ArgumentError do
            PublicPlanCreateInteractor.new(
              output_port: @output_port,
              gateway: FakePublicPlanGateway.new,
              cultivation_plan_gateway: Object.new,
              logger: @logger,
              clock: Object.new
            )
          end
          assert_match(/clock/, error.message)
        end

        test "calls on_success with the created plan_id when initialization succeeds" do
          interactor = build_interactor(
            gateway: standard_gateway,
            cultivation_plan_gateway: cultivation_gateway_returning(success_result(PlanRef.new(id: 123)))
          )

          interactor.call(standard_input)

          assert_nil @output_port.failure
          assert_instance_of Domain::PublicPlan::Dtos::PublicPlanCreateOutput, @output_port.success
          assert_equal 123, @output_port.success.plan_id
        end

        test "enqueues the optimization job chain before calling on_success" do
          job_chain = FakeJobChain.new(@output_port.events)
          interactor = build_interactor(
            gateway: standard_gateway,
            cultivation_plan_gateway: cultivation_gateway_returning(success_result(PlanRef.new(id: 123))),
            optimization_job_chain_gateway: job_chain
          )

          interactor.call(standard_input)

          assert_equal [ :enqueue, :success ], @output_port.events
          assert_equal 1, job_chain.calls.size
          assert_equal 123, job_chain.calls.first[:cultivation_plan_id]
          assert_equal "Domain::PublicPlan::Interactors::PublicPlanCreateInteractor", job_chain.calls.first[:caller_label]
        end

        test "calls on_failure when the farm is not found" do
          interactor = build_interactor(
            gateway: FakePublicPlanGateway.new(farm: nil),
            cultivation_plan_gateway: Object.new
          )

          interactor.call(standard_input)

          assert_instance_of Domain::Shared::Dtos::Error, @output_port.failure
          assert_includes @output_port.failure.message, "Farm not found"
        end

        test "calls on_failure when the farm size is invalid" do
          interactor = build_interactor(
            gateway: FakePublicPlanGateway.new(farm: standard_farm, farm_size: nil),
            cultivation_plan_gateway: Object.new
          )

          interactor.call(standard_input)

          assert_instance_of Domain::Shared::Dtos::Error, @output_port.failure
          assert_includes @output_port.failure.message, "Invalid farm size"
        end

        test "calls on_failure when the total area is not positive" do
          interactor = build_interactor(
            gateway: FakePublicPlanGateway.new(farm: standard_farm, farm_size: { id: "x", area_sqm: 0 }),
            cultivation_plan_gateway: Object.new
          )

          interactor.call(standard_input)

          assert_instance_of Domain::Shared::Dtos::Error, @output_port.failure
          assert_includes @output_port.failure.message, "Invalid total area"
        end

        test "calls on_failure with a no-crops failure when no crops are resolved" do
          interactor = build_interactor(
            gateway: FakePublicPlanGateway.new(farm: standard_farm, farm_size: { id: "home_garden", area_sqm: 30 }, crops: []),
            cultivation_plan_gateway: Object.new
          )

          interactor.call(standard_input)

          assert_instance_of Domain::PublicPlan::Dtos::PublicPlanCreateFailure, @output_port.failure
          assert @output_port.failure.no_crops?
          assert_includes @output_port.failure.message, "No crops selected"
        end

        test "calls on_failure when the cultivation plan initialization reports errors" do
          interactor = build_interactor(
            gateway: standard_gateway,
            cultivation_plan_gateway: cultivation_gateway_returning(
              Domain::CultivationPlan::Interactors::CultivationPlanInitializeInteractor::Result.new(
                cultivation_plan: nil, errors: [ "Creation failed" ]
              )
            )
          )

          interactor.call(standard_input)

          assert_instance_of Domain::Shared::Dtos::Error, @output_port.failure
          assert_includes @output_port.failure.message, "Creation failed"
        end

        test "propagates unexpected errors raised while reading the farm size" do
          interactor = build_interactor(
            gateway: FakePublicPlanGateway.new(farm: standard_farm, farm_size_error: StandardError.new("Database error")),
            cultivation_plan_gateway: Object.new
          )

          assert_raises StandardError do
            interactor.call(standard_input)
          end
        end

        private

        def build_interactor(gateway:, cultivation_plan_gateway:, optimization_job_chain_gateway: nil)
          PublicPlanCreateInteractor.new(
            output_port: @output_port,
            gateway: gateway,
            cultivation_plan_gateway: cultivation_plan_gateway,
            logger: @logger,
            clock: FIXED_CLOCK,
            optimization_job_chain_gateway: optimization_job_chain_gateway
          )
        end

        def standard_farm
          Farm.new(id: 1, name: "テスト農場", region: "Kyoto")
        end

        def standard_gateway
          FakePublicPlanGateway.new(
            farm: standard_farm,
            farm_size: { id: "home_garden", area_sqm: 30 },
            crops: [ Crop.new(id: 1, name: "トマト") ]
          )
        end

        def standard_input
          Domain::PublicPlan::Dtos::PublicPlanCreateInput.new(
            farm_id: 1, farm_size_id: "home_garden", crop_ids: [ 1 ], session_id: "session123"
          )
        end

        def success_result(plan_ref)
          Domain::CultivationPlan::Interactors::CultivationPlanInitializeInteractor::Result.new(
            cultivation_plan: plan_ref, errors: []
          )
        end

        def cultivation_gateway_returning(result)
          gateway = Object.new
          gateway.define_singleton_method(:initialize_plan_from_selection) { |**_kwargs| result }
          gateway
        end
      end
    end
  end
end
