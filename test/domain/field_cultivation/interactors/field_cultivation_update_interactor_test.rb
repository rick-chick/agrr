# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module FieldCultivation
    module Interactors
      class FieldCultivationUpdateInteractorTest < DomainLibTestCase
        test "calls on_success when gateway updates" do
          input = Domain::FieldCultivation::Dtos::FieldCultivationApiUpdateInput.new(
            field_cultivation_id: 1,
            start_date: Date.new(2026, 1, 1),
            completion_date: Date.new(2026, 1, 1) + 5,
            public_plan: false
          )
          success = Domain::FieldCultivation::Dtos::FieldCultivationApiUpdateOutput.new(
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

          FieldCultivationUpdateInteractor.new(output_port: output_port, gateway: gateway).call(input)

          assert_equal input.field_cultivation_id, seen[:field_cultivation_id]
          assert_equal input.start_date, seen[:start_date]
          assert_equal input.completion_date, seen[:completion_date]
          assert_equal false, seen[:public_plan]
          assert_equal success, received
          output_port.verify
        end

        test "calls on_failure with Error when gateway raises RecordNotFound" do
          input = Domain::FieldCultivation::Dtos::FieldCultivationApiUpdateInput.new(
            field_cultivation_id: 1,
            start_date: Date.new(2026, 1, 1),
            completion_date: Date.new(2026, 1, 1) + 5,
            public_plan: true
          )

          gateway = Object.new
          gateway.define_singleton_method(:update_field_cultivation_schedule) do |_kwargs|
            raise Domain::Shared::Exceptions::RecordNotFound, "missing"
          end

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |arg| received = arg }

          FieldCultivationUpdateInteractor.new(output_port: output_port, gateway: gateway).call(input)

          assert_instance_of Domain::Shared::Dtos::Error, received
          assert_equal "missing", received.message
          output_port.verify
        end

        test "calls on_failure with RecordInvalid when gateway raises RecordInvalid" do
          input = Domain::FieldCultivation::Dtos::FieldCultivationApiUpdateInput.new(
            field_cultivation_id: 1,
            start_date: Date.new(2026, 1, 1),
            completion_date: Date.new(2026, 1, 1) + 5,
            public_plan: false
          )

          gateway = Object.new
          gateway.define_singleton_method(:update_field_cultivation_schedule) do |_kwargs|
            raise Domain::Shared::Exceptions::RecordInvalid.new(nil, errors: [ "bad" ])
          end

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |arg| received = arg }

          FieldCultivationUpdateInteractor.new(output_port: output_port, gateway: gateway).call(input)

          assert_instance_of Domain::Shared::Exceptions::RecordInvalid, received
          output_port.verify
        end
      end
    end
  end
end
