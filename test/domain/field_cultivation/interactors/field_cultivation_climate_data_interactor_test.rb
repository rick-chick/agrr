# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module FieldCultivation
    module Interactors
      class FieldCultivationClimateDataInteractorTest < DomainLibTestCase
        def build_source(
          fc_id:,
          weather_location_id: 3,
          start_date: Date.new(2026, 1, 1),
          completion_date: Date.new(2026, 6, 1),
          predicted_weather_data: { "data" => [ { "time" => "2026-01-01" } ] }
        )
          Dtos::FieldCultivationClimateSourceSnapshot.new(
            field_cultivation_id: fc_id,
            field_name: "north",
            crop_name: "tomato",
            start_date: start_date,
            completion_date: completion_date,
            farm_id: 1,
            farm_name: "Farm",
            farm_latitude: 35.4,
            farm_longitude: 139.6,
            weather_location_id: weather_location_id,
            weather_location_timezone: "Asia/Tokyo",
            plan_id: 1,
            plan_type_public: false,
            prediction_target_end_date: nil,
            calculated_planning_end_date: nil,
            predicted_weather_data: predicted_weather_data,
            plan_crop_crop_id: 1
          )
        end

        def build_crop_entity(is_reference: false, user_id: 1)
          Domain::Crop::Entities::CropEntity.new(
            id: 1,
            user_id: user_id,
            name: "tomato",
            variety: nil,
            is_reference: is_reference
          )
        end

        def build_interactor(fc_id:, source_gateway:, crop_gateway:, weather_data_gateway: nil, weather_prediction_gateway: nil,
                             prediction_gateway: nil, cultivation_plan_gateway: nil, anchors_resolver: nil, progress_gateway: nil,
                             crop_agrr_requirement_builder: nil)
          FieldCultivationClimateDataInteractor.new(
            output_port: nil,
            logger: SilencingLoggerStub.new,
            user_id: 1,
            user_lookup: user_lookup_stub(1),
            climate_source_gateway: source_gateway,
            crop_gateway: crop_gateway,
            weather_data_gateway: weather_data_gateway || Object.new,
            weather_prediction_gateway: weather_prediction_gateway || Object.new,
            prediction_gateway: prediction_gateway || Object.new,
            cultivation_plan_gateway: cultivation_plan_gateway || Object.new,
            anchors_resolver: anchors_resolver || default_anchors_resolver,
            climate_progress_gateway: progress_gateway || Object.new,
            crop_agrr_requirement_builder: crop_agrr_requirement_builder || default_crop_agrr_requirement_builder,
            clock: Struct.new(:today).new(Date.new(2026, 3, 1)),
            translator: translator_stub
          )
        end

        def default_crop_agrr_requirement_builder
          builder = Object.new
          builder.define_singleton_method(:build_from) { |crop_source| { "crop" => { "id" => crop_source.id } } }
          builder
        end

        def default_anchors_resolver
          resolver = Object.new
          resolver.define_singleton_method(:anchors_for) do |_day|
            Domain::WeatherData::Dtos::WeatherPredictionAnchors.new(
              training_start_date: Date.new(2006, 3, 1),
              training_end_date: Date.new(2026, 2, 27),
              current_year_history_start_date: Date.new(2026, 1, 1),
              current_year_history_end_date: Date.new(2026, 2, 27),
              default_target_end_date: Date.new(2026, 9, 1)
            )
          end
          resolver
        end

        def attach_crop_find_by_id_gateway(crop_gateway, crop_entity)
          crop_gateway.define_singleton_method(:find_by_id) do |crop_id|
            raise Domain::Shared::Exceptions::RecordNotFound unless crop_id == crop_entity.id

            crop_entity
          end
          crop_gateway.define_singleton_method(:find_crop_record_with_stages!) do |crop_id|
            raise Domain::Shared::Exceptions::RecordNotFound unless crop_id == crop_entity.id

            crop_entity
          end
        end

        test "delivers climate information when gateways return data" do
          fc_id = 42
          source = build_source(fc_id: fc_id)

          source_gateway = Object.new
          attach_plan_access_snapshot_to_gateway(
            source_gateway,
            fc_id,
            snapshot: private_field_cultivation_plan_access_snapshot(fc_id, plan_user_id: 1),
            climate_source_snapshot: source
          )

          crop_entity = build_crop_entity
          crop_gateway = Object.new
          attach_crop_find_by_id_gateway(crop_gateway, crop_entity)

          weather_data_gateway = Object.new
          weather_data_gateway.define_singleton_method(:weather_data_for_period) { |**| [] }

          progress_gateway = Object.new
          progress_gateway.define_singleton_method(:calculate_progress) do |**|
            {}
          end

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:present, nil) { |arg| received = arg }

          interactor = build_interactor(
            fc_id: fc_id,
            source_gateway: source_gateway,
            crop_gateway: crop_gateway,
            weather_data_gateway: weather_data_gateway,
            progress_gateway: progress_gateway
          )
          interactor.instance_variable_set(:@output_port, output_port)

          interactor.call(
            Domain::FieldCultivation::Dtos::FieldCultivationClimateDataInput.new(
              field_cultivation_id: fc_id
            )
          )

          assert_equal fc_id, received.field_cultivation[:id]
          output_port.verify
        end

        # 認可失敗時も bundle 用 preload は 1 回走る（climate / crop 解決には進まない）。
        test "routes Forbidden through the output port when private plan is owned by another user" do
          fc_id = 42
          source_gateway = Object.new
          attach_plan_access_snapshot_to_gateway(
            source_gateway,
            fc_id,
            snapshot: private_field_cultivation_plan_access_snapshot(fc_id, plan_user_id: 99),
            climate_source_snapshot: build_source(fc_id: fc_id)
          )
          crop_gateway = Object.new
          crop_gateway.define_singleton_method(:find_by_id) do |_id|
            flunk "crop_gateway.find_by_id must not run when access is denied"
          end

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_error, nil) { |arg| received = arg }

          interactor = build_interactor(
            fc_id: fc_id,
            source_gateway: source_gateway,
            crop_gateway: crop_gateway
          )
          interactor.instance_variable_set(:@output_port, output_port)

          interactor.call(
            Domain::FieldCultivation::Dtos::FieldCultivationClimateDataInput.new(
              field_cultivation_id: fc_id
            )
          )

          assert_instance_of Domain::Shared::Dtos::Error, received
          assert_equal "Forbidden", received.message
          output_port.verify
        end

        test "routes RecordNotFound through the output port" do
          fc_id = 42
          source_gateway = Object.new
          source_gateway.define_singleton_method(:find_plan_access_snapshot_by_field_cultivation_id) do |_id|
            raise Domain::Shared::Exceptions::RecordNotFound, "gone"
          end

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_error, nil) { |arg| received = arg }

          interactor = build_interactor(
            fc_id: fc_id,
            source_gateway: source_gateway,
            crop_gateway: Object.new
          )
          interactor.instance_variable_set(:@output_port, output_port)

          interactor.call(
            Domain::FieldCultivation::Dtos::FieldCultivationClimateDataInput.new(
              field_cultivation_id: fc_id
            )
          )

          assert_instance_of Domain::Shared::Dtos::Error, received
          assert_equal "gone", received.message
          output_port.verify
        end

        test "routes missing weather location through the output port" do
          fc_id = 42
          source = build_source(fc_id: fc_id, weather_location_id: nil)

          source_gateway = Object.new
          attach_plan_access_snapshot_to_gateway(
            source_gateway,
            fc_id,
            snapshot: private_field_cultivation_plan_access_snapshot(fc_id, plan_user_id: 1),
            climate_source_snapshot: source
          )

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_error, nil) { |arg| received = arg }

          interactor = build_interactor(
            fc_id: fc_id,
            source_gateway: source_gateway,
            crop_gateway: Object.new
          )
          interactor.instance_variable_set(:@output_port, output_port)

          interactor.call(
            Domain::FieldCultivation::Dtos::FieldCultivationClimateDataInput.new(
              field_cultivation_id: fc_id
            )
          )

          assert_equal "api.errors.no_weather_data", received.message
          output_port.verify
        end

        test "routes missing cultivation period through the output port" do
          fc_id = 42
          source = build_source(fc_id: fc_id, start_date: nil, completion_date: nil)

          source_gateway = Object.new
          attach_plan_access_snapshot_to_gateway(
            source_gateway,
            fc_id,
            snapshot: private_field_cultivation_plan_access_snapshot(fc_id, plan_user_id: 1),
            climate_source_snapshot: source
          )

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_error, nil) { |arg| received = arg }

          interactor = build_interactor(
            fc_id: fc_id,
            source_gateway: source_gateway,
            crop_gateway: Object.new
          )
          interactor.instance_variable_set(:@output_port, output_port)

          interactor.call(
            Domain::FieldCultivation::Dtos::FieldCultivationClimateDataInput.new(
              field_cultivation_id: fc_id
            )
          )

          assert_equal "api.errors.no_cultivation_period", received.message
          output_port.verify
        end

        test "routes crop not found through the output port" do
          fc_id = 42
          source = build_source(fc_id: fc_id)

          source_gateway = Object.new
          attach_plan_access_snapshot_to_gateway(
            source_gateway,
            fc_id,
            snapshot: private_field_cultivation_plan_access_snapshot(fc_id, plan_user_id: 1),
            climate_source_snapshot: source
          )

          crop_entity = build_crop_entity(is_reference: false, user_id: 99)
          crop_gateway = Object.new
          attach_crop_find_by_id_gateway(crop_gateway, crop_entity)

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_error, nil) { |arg| received = arg }

          interactor = build_interactor(
            fc_id: fc_id,
            source_gateway: source_gateway,
            crop_gateway: crop_gateway
          )
          interactor.instance_variable_set(:@output_port, output_port)

          interactor.call(
            Domain::FieldCultivation::Dtos::FieldCultivationClimateDataInput.new(
              field_cultivation_id: fc_id
            )
          )

          assert_equal "api.errors.crop_not_found", received.message
          output_port.verify
        end

        test "routes invalid weather payload through the output port" do
          fc_id = 42
          source = build_source(
            fc_id: fc_id,
            predicted_weather_data: { "data" => nil }
          )

          source_gateway = Object.new
          attach_plan_access_snapshot_to_gateway(
            source_gateway,
            fc_id,
            snapshot: private_field_cultivation_plan_access_snapshot(fc_id, plan_user_id: 1),
            climate_source_snapshot: source
          )

          crop_entity = build_crop_entity
          crop_gateway = Object.new
          attach_crop_find_by_id_gateway(crop_gateway, crop_entity)

          weather_data_gateway = Object.new
          weather_data_gateway.define_singleton_method(:weather_data_for_period) { |**| [] }

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_error, nil) { |arg| received = arg }

          interactor = build_interactor(
            fc_id: fc_id,
            source_gateway: source_gateway,
            crop_gateway: crop_gateway,
            weather_data_gateway: weather_data_gateway
          )
          interactor.instance_variable_set(:@output_port, output_port)

          interactor.call(
            Domain::FieldCultivation::Dtos::FieldCultivationClimateDataInput.new(
              field_cultivation_id: fc_id
            )
          )

          assert_equal "controllers.field_cultivations.errors.weather_format_invalid", received.message
          output_port.verify
        end

        test "routes missing climate data through the output port" do
          fc_id = 99
          source = build_source(fc_id: fc_id, predicted_weather_data: nil)

          source_gateway = Object.new
          attach_plan_access_snapshot_to_gateway(
            source_gateway,
            fc_id,
            snapshot: private_field_cultivation_plan_access_snapshot(fc_id, plan_user_id: 1),
            climate_source_snapshot: source
          )
          source_gateway.define_singleton_method(:find_weather_prediction_targets_by_plan_id) do |_plan_id|
            Domain::WeatherData::Dtos::WeatherPredictionTargets.new(
              weather_location: Domain::WeatherData::Dtos::WeatherLocation.new(
                id: 1,
                latitude: 35.0,
                longitude: 139.0
              ),
              farm: Domain::WeatherData::Dtos::FarmWeatherPrediction.new(
                id: 1,
                weather_location_id: 1
              )
            )
          end

          crop_entity = build_crop_entity
          crop_gateway = Object.new
          attach_crop_find_by_id_gateway(crop_gateway, crop_entity)

          prediction_service = Object.new
          prediction_service.define_singleton_method(:predict_for_cultivation_plan) { |plan_weather:| nil }

          weather_prediction_gateway = Object.new
          weather_prediction_gateway.define_singleton_method(:prediction_service) { |weather_location:, farm:| prediction_service }

          prediction_gateway = Object.new
          prediction_gateway.define_singleton_method(:predict) { |**| nil }

          weather_data_gateway = Object.new
          weather_data_gateway.define_singleton_method(:weather_data_for_period) { |**| [] }
          weather_data_gateway.define_singleton_method(:format_for_agrr) { |**| nil }

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_error, nil) { |arg| received = arg }

          interactor = build_interactor(
            fc_id: fc_id,
            source_gateway: source_gateway,
            crop_gateway: crop_gateway,
            weather_data_gateway: weather_data_gateway,
            weather_prediction_gateway: weather_prediction_gateway,
            prediction_gateway: prediction_gateway
          )
          interactor.instance_variable_set(:@output_port, output_port)

          interactor.call(
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

        def translator_stub
          t = Object.new
          t.define_singleton_method(:t) { |key| key }
          t
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
