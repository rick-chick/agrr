# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module FieldCultivation
    module Interactors
      class FieldCultivationClimateDataInteractorTest < DomainLibTestCase
        test "delivers climate information when gateways return data" do
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

          context_gateway = Object.new
          attach_plan_access_context_to_gateway(
            context_gateway,
            fc_id,
            context: private_field_cultivation_plan_context(fc_id, plan_user_id: 1)
          )
          context_gateway.define_singleton_method(:load_context) do |field_cultivation_id:|
            raise "unexpected id" unless field_cultivation_id == fc_id

            Domain::FieldCultivation::Dtos::FieldCultivationClimateContextSnapshot.new(
              field_cultivation_id: fc_id,
              field_name: "north",
              crop_name: "tomato",
              start_date: Date.new(2026, 1, 1),
              completion_date: Date.new(2026, 6, 1),
              farm_id: 1,
              farm_name: "Farm",
              farm_latitude: 35.4,
              farm_longitude: 139.6,
              plan_id: 1,
              plan_type_public: false,
              plan_predicted_weather_present: true,
              prediction_target_end_date: nil,
              calculated_planning_end_date: nil,
              predicted_weather_data: { "data" => [] },
              crop_id: 1,
              base_temperature: 10.0,
              optimal_temperature_range: nil,
              stages: []
            )
          end

          weather_gateway = Object.new
          weather_gateway.define_singleton_method(:fetch_primary_weather_payload) do |context:, display_start_date:, display_end_date:|
            { "data" => [] }
          end
          weather_gateway.define_singleton_method(:fetch_fallback_weather_payload) { raise "unexpected fallback" }
          weather_gateway.define_singleton_method(:persist_predicted_weather_if_absent) { nil }

          progress_gateway = Object.new
          progress_gateway.define_singleton_method(:calculate_progress) do |context:, weather_payload:, use_mock:|
            {}
          end

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:present, nil) { |arg| received = arg }

          logger = SilencingLoggerStub.new

          interactor = FieldCultivationClimateDataInteractor.new(
            output_port: output_port,
            logger: logger,
            user_id: 1,
            user_lookup: user_lookup_stub(1),
            climate_gateways_for_user: lambda { |_user_dto|
              {
                context_gateway: context_gateway,
                weather_gateway: weather_gateway,
                progress_gateway: progress_gateway,
                use_mock_progress: false
              }
            }
          )

          input_dto = Domain::FieldCultivation::Dtos::FieldCultivationClimateDataInput.new(
            field_cultivation_id: fc_id
          )

          interactor.call(input_dto)

          assert_equal fc_id, received.field_cultivation[:id]
          output_port.verify
        end

        test "routes RecordNotFound through the output port" do
          fc_id = 42
          context_gateway = Object.new
          attach_plan_access_context_to_gateway(
            context_gateway,
            fc_id,
            context: private_field_cultivation_plan_context(fc_id, plan_user_id: 1)
          )
          context_gateway.define_singleton_method(:load_context) do |_kwargs|
            raise Domain::Shared::Exceptions::RecordNotFound, "gone"
          end

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_error, nil) { |arg| received = arg }

          logger = SilencingLoggerStub.new

          FieldCultivationClimateDataInteractor.new(
            output_port: output_port,
            logger: logger,
            user_id: 1,
            user_lookup: user_lookup_stub(1),
            climate_gateways_for_user: lambda { |_user_dto|
              {
                context_gateway: context_gateway,
                weather_gateway: Object.new,
                progress_gateway: Object.new,
                use_mock_progress: false
              }
            }
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
          context_gateway = Object.new
          attach_plan_access_context_to_gateway(
            context_gateway,
            fc_id,
            context: private_field_cultivation_plan_context(fc_id, plan_user_id: 1)
          )
          context_gateway.define_singleton_method(:load_context) do |field_cultivation_id:|
            Domain::FieldCultivation::Dtos::FieldCultivationClimateContextSnapshot.new(
              field_cultivation_id: field_cultivation_id,
              field_name: "x",
              crop_name: "y",
              start_date: Date.new(2026, 1, 1),
              completion_date: Date.new(2026, 6, 1),
              farm_id: 1,
              farm_name: "Farm",
              farm_latitude: 35.0,
              farm_longitude: 139.0,
              plan_id: 1,
              plan_type_public: false,
              plan_predicted_weather_present: false,
              prediction_target_end_date: nil,
              calculated_planning_end_date: nil,
              predicted_weather_data: nil,
              crop_id: 1,
              base_temperature: 10.0,
              optimal_temperature_range: nil,
              stages: []
            )
          end

          weather_gateway = Object.new
          weather_gateway.define_singleton_method(:fetch_primary_weather_payload) do |context:, display_start_date: nil, display_end_date: nil|
            nil
          end
          weather_gateway.define_singleton_method(:fetch_fallback_weather_payload) { nil }
          weather_gateway.define_singleton_method(:persist_predicted_weather_if_absent) { nil }

          progress_gateway = Object.new
          progress_gateway.define_singleton_method(:calculate_progress) { raise "unexpected progress" }

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_error, nil) { |arg| received = arg }

          logger = SilencingLoggerStub.new

          FieldCultivationClimateDataInteractor.new(
            output_port: output_port,
            logger: logger,
            user_id: 1,
            user_lookup: user_lookup_stub(1),
            climate_gateways_for_user: lambda { |_user_dto|
              {
                context_gateway: context_gateway,
                weather_gateway: weather_gateway,
                progress_gateway: progress_gateway,
                use_mock_progress: false
              }
            }
          ).call(
            Domain::FieldCultivation::Dtos::FieldCultivationClimateDataInput.new(
              field_cultivation_id: fc_id
            )
          )

          assert_instance_of Domain::Shared::Dtos::Error, received
          assert_equal "Field cultivation climate data not found", received.message
          output_port.verify
        end

        def user_lookup_stub(expected_user_id)
          user = domain_user_stub(id: expected_user_id, admin: false)
          lookup = Object.new
          lookup.define_singleton_method(:find) do |id|
            raise "unexpected user id #{id.inspect}" unless id == expected_user_id

            user
          end
          lookup
        end

        class SilencingLoggerStub
          def warn(*) end

          def info(*) end

          def error(*) end
        end
      end
    end
  end
end
