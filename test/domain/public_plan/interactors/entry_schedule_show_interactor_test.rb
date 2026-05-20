# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module PublicPlan
    module Interactors
      class EntryScheduleShowInteractorTest < DomainLibTestCase
        Result = Domain::CultivationPlan::Interactors::EntrySchedule::WindowService::Result

        test "on_success yields dto tied to injected runners" do
          weather_location = Object.new
          weather_location.define_singleton_method(:id) { 1 }
          weather_location.define_singleton_method(:region) { "jp" }
          weather_location.define_singleton_method(:latitude) { 35.0 }
          weather_location.define_singleton_method(:longitude) { 135.0 }
          weather_location.define_singleton_method(:elevation) { 100 }
          farm = Domain::Farm::Entities::FarmEntity.new(
            id: 1, name: "Farm", latitude: 35.0, longitude: 135.0, region: "jp",
            user_id: 1, created_at: nil, updated_at: nil, is_reference: true,
            weather_data_status: nil, weather_data_fetched_years: nil,
            weather_data_total_years: nil, weather_data_last_error: nil
          )
          farm.define_singleton_method(:weather_location) { weather_location }
          crop = Domain::Crop::Entities::CropEntity.new(
            id: 1, name: "Crop", name_scientific: nil, family: nil, order: nil,
            description: nil, is_reference: true, created_at: nil, updated_at: nil
          )
          crop.define_singleton_method(:crop_stages) { [] }

          prediction_payload = {
            "data" => [ { "time" => "2026-01-01" } ],
            "generated_at" => "2026-01-01T00:00:00Z",
            "prediction_end_date" => "2026-12-31"
          }

          crop_gateway = Minitest::Mock.new
          crop_gateway.expect(:list_crop_stages_by_crop_id, [], [ crop.id ])

          translator = Object.new
          def translator.t(_key, **_options)
            ""
          end

          loader_calls = []
          loader = Object.new
          loader.define_singleton_method(:load_prediction_payload!) do |**kwargs|
            loader_calls << kwargs
            prediction_payload
          end

          optimization_result = Result.new(
            eligible: false,
            reason_parts: { error: "x" },
            sowing_windows: [],
            transplant_windows: [],
            sowing_stage_id: nil,
            transplant_stage_id: nil,
            weather_end_date: Date.new(2026, 1, 5)
          )

          runner_calls = []
          runner = Object.new
          runner.define_singleton_method(:call) do |**kwargs|
            runner_calls << kwargs
            optimization_result
          end

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_success, nil) { |arg| received = arg }

          ref_date = Date.new(2026, 5, 1)
          clock = Struct.new(:today).new(ref_date)

          EntryScheduleShowInteractor.new(
            output_port: output_port,
            crop_gateway: crop_gateway,
            weather_loader: loader,
            optimization_runner: runner,
            translator: translator,
            clock: clock
          ).call(
            farm: farm,
            crop: crop,
            reference_date: ref_date,
            prediction_end_date_raw: "2026-10-01"
          )

          assert_equal 1, loader_calls.size
          assert_equal farm, loader_calls.first[:farm]
          assert_equal ref_date, loader_calls.first[:reference_date]
          assert_equal "2026-10-01", loader_calls.first[:prediction_end_date_raw]

          assert_equal 1, runner_calls.size
          assert_equal crop, runner_calls.first[:crop]
          assert_equal farm, runner_calls.first[:farm]
          assert_equal prediction_payload, runner_calls.first[:weather_payload]

          assert_instance_of Domain::PublicPlan::Dtos::EntryScheduleShowOutput, received
          assert_equal farm.id, received.farm_fragment[:id]
          assert_equal 2026, received.prediction_fragment[:chart_calendar_year]
          assert_equal crop.id, received.crop_fragment[:id]

          crop_gateway.verify
          output_port.verify
        end
      end
    end
  end
end
