# frozen_string_literal: true

require "test_helper"

module Domain
  module PublicPlan
    module Interactors
      class PublicPlanCreateInteractorTest < ActiveSupport::TestCase
        test "calls on_success with plan_id when gateway succeeds" do
          farm = create(:farm)
          farm_size = { id: 'home_garden', area_sqm: 30 }
          crops = [create(:crop)]
          cultivation_plan = create(:cultivation_plan, id: 123, farm: farm)

          # Mock CultivationPlanCreator result
          creator_result = CultivationPlanCreator::Result.new(
            cultivation_plan: cultivation_plan,
            errors: []
          )

          gateway = Minitest::Mock.new
          gateway.expect(:find_farm, farm, [farm.id])
          gateway.expect(:find_farm_size, farm_size, ['home_garden'])
          gateway.expect(:find_crops, crops, [[1]])
          gateway.expect(:create, creator_result, [Domain::PublicPlan::Dtos::PublicPlanCreateGatewayDto])

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_success, nil) { |arg| received = arg }

          interactor = PublicPlanCreateInteractor.new(output_port: output_port, gateway: gateway)
          input_dto = Domain::PublicPlan::Dtos::PublicPlanCreateInputDto.new(
            farm_id: farm.id,
            farm_size_id: 'home_garden',
            crop_ids: [1],
            session_id: 'session123'
          )

          interactor.call(input_dto)

          assert_instance_of Domain::PublicPlan::Dtos::PublicPlanCreateSuccessDto, received
          assert_equal 123, received.plan_id
          gateway.verify
          output_port.verify
        end

        test "calls on_failure when farm not found" do
          gateway = Minitest::Mock.new
          gateway.expect(:find_farm, nil, [999])

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |arg| received = arg }

          interactor = PublicPlanCreateInteractor.new(output_port: output_port, gateway: gateway)
          input_dto = Domain::PublicPlan::Dtos::PublicPlanCreateInputDto.new(
            farm_id: 999,
            farm_size_id: 'home_garden',
            crop_ids: [1],
            session_id: 'session123'
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
          gateway.expect(:find_farm, farm, [farm.id])
          gateway.expect(:find_farm_size, nil, ['invalid_size'])

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |arg| received = arg }

          interactor = PublicPlanCreateInteractor.new(output_port: output_port, gateway: gateway)
          input_dto = Domain::PublicPlan::Dtos::PublicPlanCreateInputDto.new(
            farm_id: farm.id,
            farm_size_id: 'invalid_size',
            crop_ids: [1],
            session_id: 'session123'
          )

          interactor.call(input_dto)

          assert_instance_of Domain::Shared::Dtos::ErrorDto, received
          assert_includes received.message, "Invalid farm size"
          gateway.verify
          output_port.verify
        end

        test "calls on_failure when total_area is invalid" do
          farm = create(:farm)
          farm_size = { id: 'invalid', area_sqm: 0 }
          gateway = Minitest::Mock.new
          gateway.expect(:find_farm, farm, [farm.id])
          gateway.expect(:find_farm_size, farm_size, ['invalid'])

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |arg| received = arg }

          interactor = PublicPlanCreateInteractor.new(output_port: output_port, gateway: gateway)
          input_dto = Domain::PublicPlan::Dtos::PublicPlanCreateInputDto.new(
            farm_id: farm.id,
            farm_size_id: 'invalid',
            crop_ids: [1],
            session_id: 'session123'
          )

          interactor.call(input_dto)

          assert_instance_of Domain::Shared::Dtos::ErrorDto, received
          assert_includes received.message, "Invalid total area"
          gateway.verify
          output_port.verify
        end

        test "calls on_failure when no crops selected" do
          farm = create(:farm)
          farm_size = { id: 'home_garden', area_sqm: 30 }
          gateway = Minitest::Mock.new
          gateway.expect(:find_farm, farm, [farm.id])
          gateway.expect(:find_farm_size, farm_size, ['home_garden'])
          gateway.expect(:find_crops, [], [[1]])

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |arg| received = arg }

          interactor = PublicPlanCreateInteractor.new(output_port: output_port, gateway: gateway)
          input_dto = Domain::PublicPlan::Dtos::PublicPlanCreateInputDto.new(
            farm_id: farm.id,
            farm_size_id: 'home_garden',
            crop_ids: [1],
            session_id: 'session123'
          )

          interactor.call(input_dto)

          assert_instance_of Domain::Shared::Dtos::ErrorDto, received
          assert_includes received.message, "No crops selected"
          gateway.verify
          output_port.verify
        end

        test "calls on_failure when creation fails" do
          farm = create(:farm)
          farm_size = { id: 'home_garden', area_sqm: 30 }
          crops = [create(:crop)]

          # Mock failed CultivationPlanCreator result
          creator_result = CultivationPlanCreator::Result.new(
            cultivation_plan: nil,
            errors: ["Creation failed"]
          )

          gateway = Minitest::Mock.new
          gateway.expect(:find_farm, farm, [farm.id])
          gateway.expect(:find_farm_size, farm_size, ['home_garden'])
          gateway.expect(:find_crops, crops, [[1]])
          gateway.expect(:create, creator_result, [Domain::PublicPlan::Dtos::PublicPlanCreateGatewayDto])

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |arg| received = arg }

          interactor = PublicPlanCreateInteractor.new(output_port: output_port, gateway: gateway)
          input_dto = Domain::PublicPlan::Dtos::PublicPlanCreateInputDto.new(
            farm_id: farm.id,
            farm_size_id: 'home_garden',
            crop_ids: [1],
            session_id: 'session123'
          )

          interactor.call(input_dto)

          assert_instance_of Domain::Shared::Dtos::ErrorDto, received
          assert_includes received.message, "Creation failed"
          gateway.verify
          output_port.verify
        end

        test "calls on_failure when unexpected error occurs" do
          farm = create(:farm)
          gateway = Minitest::Mock.new
          gateway.expect(:find_farm, farm, [farm.id])
          gateway.expect(:find_farm_size, nil) { raise StandardError, "Database error" }

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |arg| received = arg }

          interactor = PublicPlanCreateInteractor.new(output_port: output_port, gateway: gateway)
          input_dto = Domain::PublicPlan::Dtos::PublicPlanCreateInputDto.new(
            farm_id: farm.id,
            farm_size_id: 'home_garden',
            crop_ids: [1],
            session_id: 'session123'
          )

          interactor.call(input_dto)

          assert_instance_of Domain::Shared::Dtos::ErrorDto, received
          assert_includes received.message, "Database error"
          gateway.verify
          output_port.verify
        end
      end
    end
  end
end
