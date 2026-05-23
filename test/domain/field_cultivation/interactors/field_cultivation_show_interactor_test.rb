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

          call_args = nil
          gateway = Object.new
          gateway.define_singleton_method(:find_api_summary) do |field_cultivation_id:|
            call_args = field_cultivation_id
            dto
          end

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_success, nil) { |arg| received = arg }

          FieldCultivationShowInteractor.new(output_port: output_port, gateway: gateway).call(field_cultivation_id: fc_id.to_s)

          assert_equal fc_id.to_s, call_args.to_s

          assert_equal dto, received
          output_port.verify
        end

        test "calls on_failure with Error when gateway raises RecordNotFound" do
          fc_id = 99
          gateway = Object.new
          gateway.define_singleton_method(:find_api_summary) do |_kwargs|
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
