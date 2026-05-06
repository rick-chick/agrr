# frozen_string_literal: true

require "test_helper"

module Domain
  module FieldCultivation
    module Interactors
      class FieldCultivationApiShowInteractorTest < ActiveSupport::TestCase
        test "calls on_success when gateway returns summary dto" do
          fc_id = 42
          dto = Domain::FieldCultivation::Dtos::FieldCultivationApiSummaryDto.new(
            id: fc_id,
            field_name: "F",
            crop_name: "C",
            area: 1.0,
            start_date: Date.current,
            completion_date: Date.current + 1,
            cultivation_days: 2,
            estimated_cost: 3,
            gdd: 4,
            status: "completed"
          )

          call_args = nil
          gateway = Object.new
          gateway.define_singleton_method(:fetch_api_summary) do |field_cultivation_id:|
            call_args = field_cultivation_id
            dto
          end

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_success, nil) { |arg| received = arg }

          FieldCultivationApiShowInteractor.new(output_port: output_port, gateway: gateway).call(field_cultivation_id: fc_id.to_s)

          assert_equal fc_id.to_s, call_args.to_s

          assert_equal dto, received
          output_port.verify
        end

        test "calls on_failure with ErrorDto when gateway raises RecordNotFound" do
          fc_id = 99
          gateway = Object.new
          gateway.define_singleton_method(:fetch_api_summary) do |_kwargs|
            raise Domain::Shared::Exceptions::RecordNotFound, "gone"
          end

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |arg| received = arg }

          FieldCultivationApiShowInteractor.new(output_port: output_port, gateway: gateway).call(field_cultivation_id: fc_id)

          assert_instance_of Domain::Shared::Dtos::ErrorDto, received
          assert_equal "gone", received.message
          output_port.verify
        end
      end

      class FieldCultivationApiUpdateInteractorTest < ActiveSupport::TestCase
        test "calls on_success when gateway updates" do
          input = Domain::FieldCultivation::Dtos::FieldCultivationApiUpdateInputDto.new(
            field_cultivation_id: 1,
            start_date: Date.current,
            completion_date: Date.current + 5,
            public_plan: false
          )
          success = Domain::FieldCultivation::Dtos::FieldCultivationApiUpdateSuccessDto.new(
            field_cultivation_id: 1,
            start_date: input.start_date,
            completion_date: input.completion_date
          )

          seen = {}
          gateway = Object.new
          gateway.define_singleton_method(:update_field_cultivation_schedule) do |field_cultivation_id:, start_date:, completion_date:, public_plan:|
            seen[:field_cultivation_id] = field_cultivation_id
            seen[:start_date] = start_date
            seen[:completion_date] = completion_date
            seen[:public_plan] = public_plan
            success
          end

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_success, nil) { |arg| received = arg }

          FieldCultivationApiUpdateInteractor.new(output_port: output_port, gateway: gateway).call(input)

          assert_equal input.field_cultivation_id, seen[:field_cultivation_id]
          assert_equal input.start_date, seen[:start_date]
          assert_equal input.completion_date, seen[:completion_date]
          assert_equal false, seen[:public_plan]
          assert_equal success, received
          output_port.verify
        end

        test "calls on_failure with ErrorDto when gateway raises RecordNotFound" do
          input = Domain::FieldCultivation::Dtos::FieldCultivationApiUpdateInputDto.new(
            field_cultivation_id: 1,
            start_date: Date.current,
            completion_date: Date.current + 5,
            public_plan: true
          )

          gateway = Object.new
          gateway.define_singleton_method(:update_field_cultivation_schedule) do |_kwargs|
            raise Domain::Shared::Exceptions::RecordNotFound, "missing"
          end

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |arg| received = arg }

          FieldCultivationApiUpdateInteractor.new(output_port: output_port, gateway: gateway).call(input)

          assert_instance_of Domain::Shared::Dtos::ErrorDto, received
          assert_equal "missing", received.message
          output_port.verify
        end

        test "calls on_failure with RecordInvalid when gateway raises RecordInvalid" do
          input = Domain::FieldCultivation::Dtos::FieldCultivationApiUpdateInputDto.new(
            field_cultivation_id: 1,
            start_date: Date.current,
            completion_date: Date.current + 5,
            public_plan: false
          )

          gateway = Object.new
          gateway.define_singleton_method(:update_field_cultivation_schedule) do |_kwargs|
            raise Domain::Shared::Exceptions::RecordInvalid.new(nil, errors: [ "bad" ])
          end

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |arg| received = arg }

          FieldCultivationApiUpdateInteractor.new(output_port: output_port, gateway: gateway).call(input)

          assert_instance_of Domain::Shared::Exceptions::RecordInvalid, received
          output_port.verify
        end
      end
    end
  end
end
