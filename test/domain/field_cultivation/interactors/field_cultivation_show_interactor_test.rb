# frozen_string_literal: true

require "test_helper"

module Domain
  module FieldCultivation
    module Interactors
      class FieldCultivationShowInteractorTest < ActiveSupport::TestCase
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

          FieldCultivationShowInteractor.new(output_port: output_port, gateway: gateway).call(field_cultivation_id: fc_id.to_s)

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

          FieldCultivationShowInteractor.new(output_port: output_port, gateway: gateway).call(field_cultivation_id: fc_id)

          assert_instance_of Domain::Shared::Dtos::ErrorDto, received
          assert_equal "gone", received.message
          output_port.verify
        end
      end
    end
  end
end
