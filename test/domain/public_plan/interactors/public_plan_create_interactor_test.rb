# frozen_string_literal: true

require "test_helper"

module Domain
  module PublicPlan
    module Interactors
      class PublicPlanCreateInteractorTest < ActiveSupport::TestCase
        FIXED_PUBLIC_PLAN_CLOCK = Struct.new(:date) do
          def today
            date
          end
        end.new(Date.new(2025, 4, 1))

        test "requires clock responding to today" do
          farm = create(:farm)
          gateway = Minitest::Mock.new
          gateway.expect(:find_farm, farm, [ farm.id ])

          output_port = Minitest::Mock.new

          error = assert_raises(ArgumentError) do
            PublicPlanCreateInteractor.new(
              output_port: output_port,
              gateway: gateway,
              cultivation_plan_gateway: Minitest::Mock.new,
              logger: Adapters::Logger::Gateways::RailsLoggerGateway.new,
              clock: Object.new
            )
          end
          assert_match(/clock/, error.message)
        end

        test "calls on_success with plan_id when cultivation gateway succeeds" do
          farm = create(:farm)
          farm_size = { id: "home_garden", area_sqm: 30 }
          crops = [ create(:crop) ]
          cultivation_plan = create(:cultivation_plan, id: 123, farm: farm)

          creator_result = Domain::CultivationPlan::Interactors::CultivationPlanInitializeInteractor::Result.new(
            cultivation_plan: cultivation_plan,
            errors: []
          )

          gateway = Minitest::Mock.new
          gateway.expect(:find_farm, farm, [ farm.id ])
          gateway.expect(:find_farm_size, farm_size, [ "home_garden" ])
          gateway.expect(:find_crops, crops, [ [ 1 ] ])

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_success, nil) { |arg| received = arg }

          interactor = PublicPlanCreateInteractor.new(
            output_port: output_port,
            gateway: gateway,
            cultivation_plan_gateway: cultivation_gateway_returning(creator_result),
            logger: Adapters::Logger::Gateways::RailsLoggerGateway.new,
            clock: FIXED_PUBLIC_PLAN_CLOCK
          )
          input_dto = Domain::PublicPlan::Dtos::PublicPlanCreateInputDto.new(
            farm_id: farm.id,
            farm_size_id: "home_garden",
            crop_ids: [ 1 ],
            session_id: "session123"
          )

          interactor.call(input_dto)

          assert_instance_of Domain::PublicPlan::Dtos::PublicPlanCreateSuccessDto, received
          assert_equal 123, received.plan_id
          gateway.verify
          output_port.verify
        end

        test "calls optimization_job_chain_gateway before on_success with plan_id" do
          farm = create(:farm)
          farm_size = { id: "home_garden", area_sqm: 30 }
          crops = [ create(:crop) ]
          cultivation_plan = create(:cultivation_plan, id: 123, farm: farm)

          creator_result = Domain::CultivationPlan::Interactors::CultivationPlanInitializeInteractor::Result.new(
            cultivation_plan: cultivation_plan,
            errors: []
          )

          gateway = Minitest::Mock.new
          gateway.expect(:find_farm, farm, [ farm.id ])
          gateway.expect(:find_farm_size, farm_size, [ "home_garden" ])
          gateway.expect(:find_crops, crops, [ [ 1 ] ])

          sequence = []
          opt_gateway = Object.new
          opt_gateway.define_singleton_method(:enqueue_after_create!) do |cultivation_plan_id:, caller_label:, redirect_path: nil|
            sequence << [ :enqueue, cultivation_plan_id, caller_label, redirect_path ]
          end

          received = nil
          output_port = Object.new
          output_port.define_singleton_method(:on_success) do |dto|
            sequence << [ :success, dto.plan_id ]
            received = dto
          end

          interactor = PublicPlanCreateInteractor.new(
            output_port: output_port,
            gateway: gateway,
            cultivation_plan_gateway: cultivation_gateway_returning(creator_result),
            logger: Adapters::Logger::Gateways::RailsLoggerGateway.new,
            clock: FIXED_PUBLIC_PLAN_CLOCK,
            optimization_job_chain_gateway: opt_gateway
          )
          input_dto = Domain::PublicPlan::Dtos::PublicPlanCreateInputDto.new(
            farm_id: farm.id,
            farm_size_id: "home_garden",
            crop_ids: [ 1 ],
            session_id: "session123"
          )

          interactor.call(input_dto)

          assert_equal [
            [ :enqueue, 123, "Domain::PublicPlan::Interactors::PublicPlanCreateInteractor", nil ],
            [ :success, 123 ]
          ], sequence
          assert_instance_of Domain::PublicPlan::Dtos::PublicPlanCreateSuccessDto, received
          assert_equal 123, received.plan_id
          gateway.verify
        end

        test "calls on_failure when farm not found" do
          gateway = Minitest::Mock.new
          gateway.expect(:find_farm, nil, [ 999 ])

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |arg| received = arg }

          interactor = PublicPlanCreateInteractor.new(
            output_port: output_port,
            gateway: gateway,
            cultivation_plan_gateway: Minitest::Mock.new,
            logger: Adapters::Logger::Gateways::RailsLoggerGateway.new,
            clock: FIXED_PUBLIC_PLAN_CLOCK
          )
          input_dto = Domain::PublicPlan::Dtos::PublicPlanCreateInputDto.new(
            farm_id: 999,
            farm_size_id: "home_garden",
            crop_ids: [ 1 ],
            session_id: "session123"
          )

          interactor.call(input_dto)

          assert_instance_of Domain::Shared::Dtos::ErrorDto, received
          assert_includes received.message, "Farm not found"
          gateway.verify
          output_port.verify
        end

        test "calls on_failure when farm_size is invalid" do
          farm = create(:farm)
          gateway = Minitest::Mock.new
          gateway.expect(:find_farm, farm, [ farm.id ])
          gateway.expect(:find_farm_size, nil, [ "invalid_size" ])

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |arg| received = arg }

          interactor = PublicPlanCreateInteractor.new(
            output_port: output_port,
            gateway: gateway,
            cultivation_plan_gateway: Minitest::Mock.new,
            logger: Adapters::Logger::Gateways::RailsLoggerGateway.new,
            clock: FIXED_PUBLIC_PLAN_CLOCK
          )
          input_dto = Domain::PublicPlan::Dtos::PublicPlanCreateInputDto.new(
            farm_id: farm.id,
            farm_size_id: "invalid_size",
            crop_ids: [ 1 ],
            session_id: "session123"
          )

          interactor.call(input_dto)

          assert_instance_of Domain::Shared::Dtos::ErrorDto, received
          assert_includes received.message, "Invalid farm size"
          gateway.verify
          output_port.verify
        end

        test "calls on_failure when total_area is invalid" do
          farm = create(:farm)
          farm_size = { id: "invalid", area_sqm: 0 }
          gateway = Minitest::Mock.new
          gateway.expect(:find_farm, farm, [ farm.id ])
          gateway.expect(:find_farm_size, farm_size, [ "invalid" ])

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |arg| received = arg }

          interactor = PublicPlanCreateInteractor.new(
            output_port: output_port,
            gateway: gateway,
            cultivation_plan_gateway: Minitest::Mock.new,
            logger: Adapters::Logger::Gateways::RailsLoggerGateway.new,
            clock: FIXED_PUBLIC_PLAN_CLOCK
          )
          input_dto = Domain::PublicPlan::Dtos::PublicPlanCreateInputDto.new(
            farm_id: farm.id,
            farm_size_id: "invalid",
            crop_ids: [ 1 ],
            session_id: "session123"
          )

          interactor.call(input_dto)

          assert_instance_of Domain::Shared::Dtos::ErrorDto, received
          assert_includes received.message, "Invalid total area"
          gateway.verify
          output_port.verify
        end

        test "calls on_failure when no crops selected" do
          farm = create(:farm)
          farm_size = { id: "home_garden", area_sqm: 30 }
          gateway = Minitest::Mock.new
          gateway.expect(:find_farm, farm, [ farm.id ])
          gateway.expect(:find_farm_size, farm_size, [ "home_garden" ])
          gateway.expect(:find_crops, [], [ [ 1 ] ])

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |arg| received = arg }

          interactor = PublicPlanCreateInteractor.new(
            output_port: output_port,
            gateway: gateway,
            cultivation_plan_gateway: Minitest::Mock.new,
            logger: Adapters::Logger::Gateways::RailsLoggerGateway.new,
            clock: FIXED_PUBLIC_PLAN_CLOCK
          )
          input_dto = Domain::PublicPlan::Dtos::PublicPlanCreateInputDto.new(
            farm_id: farm.id,
            farm_size_id: "home_garden",
            crop_ids: [ 1 ],
            session_id: "session123"
          )

          interactor.call(input_dto)

          assert_instance_of Domain::Shared::Dtos::ErrorDto, received
          assert_includes received.message, "No crops selected"
          gateway.verify
          output_port.verify
        end

        test "calls on_failure when creation fails" do
          farm = create(:farm)
          farm_size = { id: "home_garden", area_sqm: 30 }
          crops = [ create(:crop) ]

          creator_result = Domain::CultivationPlan::Interactors::CultivationPlanInitializeInteractor::Result.new(
            cultivation_plan: nil,
            errors: [ "Creation failed" ]
          )

          gateway = Minitest::Mock.new
          gateway.expect(:find_farm, farm, [ farm.id ])
          gateway.expect(:find_farm_size, farm_size, [ "home_garden" ])
          gateway.expect(:find_crops, crops, [ [ 1 ] ])

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |arg| received = arg }

          interactor = PublicPlanCreateInteractor.new(
            output_port: output_port,
            gateway: gateway,
            cultivation_plan_gateway: cultivation_gateway_returning(creator_result),
            logger: Adapters::Logger::Gateways::RailsLoggerGateway.new,
            clock: FIXED_PUBLIC_PLAN_CLOCK
          )
          input_dto = Domain::PublicPlan::Dtos::PublicPlanCreateInputDto.new(
            farm_id: farm.id,
            farm_size_id: "home_garden",
            crop_ids: [ 1 ],
            session_id: "session123"
          )

          interactor.call(input_dto)

          assert_instance_of Domain::Shared::Dtos::ErrorDto, received
          assert_includes received.message, "Creation failed"
          gateway.verify
          output_port.verify
        end

        test "propagates unexpected error from find_farm_size" do
          farm = create(:farm)
          gateway = Minitest::Mock.new
          gateway.expect(:find_farm, farm, [ farm.id ])
          gateway.expect(:find_farm_size, nil) { raise StandardError, "Database error" }

          output_port = Minitest::Mock.new

          interactor = PublicPlanCreateInteractor.new(
            output_port: output_port,
            gateway: gateway,
            cultivation_plan_gateway: Minitest::Mock.new,
            logger: Adapters::Logger::Gateways::RailsLoggerGateway.new,
            clock: FIXED_PUBLIC_PLAN_CLOCK
          )
          input_dto = Domain::PublicPlan::Dtos::PublicPlanCreateInputDto.new(
            farm_id: farm.id,
            farm_size_id: "home_garden",
            crop_ids: [ 1 ],
            session_id: "session123"
          )

          assert_raises(StandardError, "Database error") do
            interactor.call(input_dto)
          end

          gateway.verify
        end

        private

        def cultivation_gateway_returning(result)
          gw = Object.new
          gw.define_singleton_method(:initialize_plan_from_selection) { |**_kwargs| result }
          gw
        end
      end
    end
  end
end
