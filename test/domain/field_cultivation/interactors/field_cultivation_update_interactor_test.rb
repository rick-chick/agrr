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
          attach_plan_access_context_to_gateway(gateway, input.field_cultivation_id)
          gateway.define_singleton_method(:update_field_cultivation_schedule) do |field_cultivation_id:, start_date:, completion_date:, cultivation_days:|
            seen[:field_cultivation_id] = field_cultivation_id
            seen[:start_date] = start_date
            seen[:completion_date] = completion_date
            seen[:cultivation_days] = cultivation_days
            success
          end

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_success, nil) { |arg| received = arg }

          FieldCultivationUpdateInteractor.new(output_port: output_port, gateway: gateway).call(input)

          assert_equal input.field_cultivation_id, seen[:field_cultivation_id]
          assert_equal input.start_date, seen[:start_date]
          assert_equal input.completion_date, seen[:completion_date]
          assert_nil seen[:cultivation_days]
          assert_equal success, received
          output_port.verify
        end

        test "calls on_failure with Forbidden when private plan is owned by another user" do
          input = Domain::FieldCultivation::Dtos::FieldCultivationApiUpdateInput.new(
            field_cultivation_id: 1,
            start_date: Date.new(2026, 1, 1),
            completion_date: Date.new(2026, 1, 1) + 5,
            public_plan: false
          )

          gateway = Object.new
          attach_plan_access_context_to_gateway(
            gateway,
            input.field_cultivation_id,
            context: private_field_cultivation_plan_context(input.field_cultivation_id, plan_user_id: 99)
          )
          gateway.define_singleton_method(:update_field_cultivation_schedule) do |_kwargs|
            flunk "update must not run when access is denied"
          end

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, domain_user_stub(id: 1), [ 1 ])

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |arg| received = arg }

          FieldCultivationUpdateInteractor.new(
            output_port: output_port,
            gateway: gateway,
            user_id: 1,
            user_lookup: user_lookup
          ).call(input)

          assert_instance_of Domain::Shared::Dtos::Error, received
          assert_equal "Forbidden", received.message
          output_port.verify
          user_lookup.verify
        end

        test "calls on_failure with Error when gateway raises RecordNotFound" do
          input = Domain::FieldCultivation::Dtos::FieldCultivationApiUpdateInput.new(
            field_cultivation_id: 1,
            start_date: Date.new(2026, 1, 1),
            completion_date: Date.new(2026, 1, 1) + 5,
            public_plan: true
          )

          gateway = Object.new
          attach_plan_access_context_to_gateway(gateway, input.field_cultivation_id)
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
          attach_plan_access_context_to_gateway(gateway, input.field_cultivation_id)
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
