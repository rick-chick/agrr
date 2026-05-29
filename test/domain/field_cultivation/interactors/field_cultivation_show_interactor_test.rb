# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module FieldCultivation
    module Interactors
      class FieldCultivationShowInteractorTest < DomainLibTestCase
        test "calls on_success when gateway returns summary dto" do
          fc_id = 42
          dto = Domain::FieldCultivation::Dtos::FieldCultivationApiSummary.new(
            id: fc_id,
            field_name: "F",
            crop_name: "C",
            area: 1.0,
            start_date: Date.new(2026, 1, 1),
            completion_date: Date.new(2026, 1, 1) + 1,
            cultivation_days: 2,
            estimated_cost: 3,
            gdd: 4,
            status: "completed"
          )

          gateway = Object.new
          api_summary_snapshot = Struct.new(
            :id, :field_name, :crop_name, :area, :start_date, :completion_date,
            :cultivation_days, :estimated_cost, :gdd, :status
          ).new(
            dto.id, dto.field_name, dto.crop_name, dto.area, dto.start_date, dto.completion_date,
            dto.cultivation_days, dto.estimated_cost, dto.gdd, dto.status
          )
          attach_plan_access_snapshot_to_gateway(gateway, fc_id, api_summary_snapshot: api_summary_snapshot)

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_success, nil) { |arg| received = arg }

          FieldCultivationShowInteractor.new(output_port: output_port, gateway: gateway).call(field_cultivation_id: fc_id.to_s)

          assert_equal dto.id, received.id
          assert_equal dto.field_name, received.field_name
          assert_equal dto.status, received.status
          output_port.verify
        end

        test "calls on_failure with Forbidden when private plan is owned by another user" do
          fc_id = 7
          gateway = Object.new
          attach_plan_access_snapshot_to_gateway(
            gateway,
            fc_id,
            snapshot: private_field_cultivation_plan_access_snapshot(fc_id, plan_user_id: 99)
          )

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, domain_user_stub(id: 1), [ 1 ])

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |arg| received = arg }

          FieldCultivationShowInteractor.new(
            output_port: output_port,
            gateway: gateway,
            user_id: 1,
            user_lookup: user_lookup
          ).call(field_cultivation_id: fc_id)

          assert_instance_of Domain::Shared::Dtos::Error, received
          assert_equal "Forbidden", received.message
          output_port.verify
          user_lookup.verify
        end

        test "calls on_failure with Error when gateway raises RecordNotFound" do
          fc_id = 99
          gateway = Object.new
          gateway.define_singleton_method(:find_plan_access_snapshot_by_field_cultivation_id) do |_id|
            raise Domain::Shared::Exceptions::RecordNotFound, "gone"
          end

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |arg| received = arg }

          FieldCultivationShowInteractor.new(output_port: output_port, gateway: gateway).call(field_cultivation_id: fc_id)

          assert_instance_of Domain::Shared::Dtos::Error, received
          assert_equal "gone", received.message
          output_port.verify
        end
      end
    end
  end
end
