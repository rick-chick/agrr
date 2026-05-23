# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module FieldCultivation
    module Interactors
      class FieldCultivationClimateDataInteractorTest < DomainLibTestCase
        test "delivers climate information when gateway returns data" do
          fc_id = 42
          success_dto = Domain::FieldCultivation::Dtos::FieldCultivationClimateDataOutput.new(
            field_cultivation: { id: fc_id, field_name: "north", crop_name: "tomato" },
            farm: { id: 1, name: "Yokohama Farm", latitude: 35.4, longitude: 139.6 },
            crop_requirements: { base_temperature: 10.0 },
            weather_data: [],
            gdd_data: [],
            stages: [],
            progress_result: {},
            debug_info: {}
          )

          fetch_args = {}
          gateway = Object.new
          gateway.define_singleton_method(:find_climate_data) do |field_cultivation_id:, display_start_date:, display_end_date:|
            fetch_args[:field_cultivation_id] = field_cultivation_id
            fetch_args[:display_start_date] = display_start_date
            fetch_args[:display_end_date] = display_end_date
            success_dto
          end

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:present, nil) { |arg| received = arg }

          logger = SilencingLoggerStub.new

          interactor = FieldCultivationClimateDataInteractor.new(
            output_port: output_port,
            gateway: gateway,
            logger: logger
          )

          input_dto = Domain::FieldCultivation::Dtos::FieldCultivationClimateDataInput.new(
            field_cultivation_id: fc_id
          )

          interactor.call(input_dto)

          assert_equal fc_id, fetch_args[:field_cultivation_id]
          assert_nil fetch_args[:display_start_date]
          assert_nil fetch_args[:display_end_date]
          assert_equal success_dto, received
          output_port.verify
        end

        test "routes RecordNotFound through the output port" do
          fc_id = 42
          gateway = Object.new
          gateway.define_singleton_method(:find_climate_data) do |_kwargs|
            raise Domain::Shared::Exceptions::RecordNotFound, "gone"
          end

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_error, nil) { |arg| received = arg }

          logger = SilencingLoggerStub.new

          FieldCultivationClimateDataInteractor.new(
            output_port: output_port,
            gateway: gateway,
            logger: logger
          ).call(
            Domain::FieldCultivation::Dtos::FieldCultivationClimateDataInput.new(
              field_cultivation_id: fc_id
            )
          )

          assert_instance_of Domain::Shared::Dtos::Error, received
          assert_equal "gone", received.message
          output_port.verify
        end

        test "routes missing climate data through the output port" do
          fc_id = 99
          gateway = Object.new
          gateway.define_singleton_method(:find_climate_data) do |_kwargs|
            nil
          end

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_error, nil) { |arg| received = arg }

          logger = SilencingLoggerStub.new

          FieldCultivationClimateDataInteractor.new(
            output_port: output_port,
            gateway: gateway,
            logger: logger
          ).call(
            Domain::FieldCultivation::Dtos::FieldCultivationClimateDataInput.new(
              field_cultivation_id: fc_id
            )
          )

          assert_instance_of Domain::Shared::Dtos::Error, received
          assert_equal "Field cultivation climate data not found", received.message
          output_port.verify
        end

        # Minimal logger for unit tests (Interactor may call warn/info).
        class SilencingLoggerStub
          def warn(*) end

          def info(*) end

          def error(*) end
        end
      end
    end
  end
end
