# frozen_string_literal: true

require "test_helper"

module Adapters
  module FieldCultivation
    module Gateways
      class FieldCultivationClimateActiveRecordGatewayTest < ActiveSupport::TestCase
        def setup
          @user = create(:user)
          weather_location = create(:weather_location)
          @farm = create(:farm, user: @user, weather_location: weather_location)
          @plan = create(:cultivation_plan, farm: @farm, user: @user)
          @crop = create(:crop, :with_stages, user: @user)
          @plan_crop = create(:cultivation_plan_crop, cultivation_plan: @plan, crop: @crop)
          @plan_field = create(:cultivation_plan_field, cultivation_plan: @plan)
          @field_cultivation = create(
            :field_cultivation,
            cultivation_plan: @plan,
            cultivation_plan_crop: @plan_crop,
            cultivation_plan_field: @plan_field,
            start_date: Date.current,
            completion_date: Date.current + 1
          )
        end

        def climate_bundle(use_mock_progress: false)
          CompositionRoot.field_cultivation_climate_gateways_bundle_for(
            @user,
            use_mock_progress: use_mock_progress
          )
        end

        def assemble_climate_dto(bundle, field_cultivation_id:)
          context = bundle.fetch(:context_gateway).load_context(field_cultivation_id: field_cultivation_id)
          weather_payload = bundle.fetch(:weather_gateway).fetch_primary_weather_payload(context: context)
          weather_records = Domain::FieldCultivation::Mappers::FieldCultivationClimateDataMapper.extract_weather_records(
            weather_payload,
            context.start_date,
            context.completion_date
          )
          progress_result = bundle.fetch(:progress_gateway).calculate_progress(
            context: context,
            weather_payload: weather_payload,
            use_mock: bundle.fetch(:use_mock_progress)
          )
          Domain::FieldCultivation::Mappers::FieldCultivationClimateDataMapper.build_output(
            context: context,
            weather_records: weather_records,
            progress_result: progress_result
          )
        end

        test "returns climate dto for authorized field cultivation" do
          start_date = @field_cultivation.start_date
          weather_data_cli = {
            "data" => [
              {
                "time" => start_date.to_s,
                "temperature_2m_max" => 25.0,
                "temperature_2m_min" => 15.0,
                "temperature_2m_mean" => 20.0
              }
            ]
          }

          progress_result = {
            "progress_records" => [
              { "date" => start_date.to_s, "cumulative_gdd" => 5.0, "stage_name" => "Stage 1" }
            ]
          }

          progress_gateway = mock("AgrrProgressGateway")
          progress_gateway
            .expects(:calculate_progress)
            .with(
              crop: @crop,
              start_date: @field_cultivation.start_date,
              weather_data: weather_data_cli
            )
            .returns(progress_result)

          bundle = climate_bundle(use_mock_progress: false)
          bundle.fetch(:weather_gateway).stubs(:fetch_primary_weather_payload).returns(weather_data_cli)
          CompositionRoot.stubs(:agrr_progress_gateway).returns(progress_gateway)

          dto = assemble_climate_dto(bundle, field_cultivation_id: @field_cultivation.id)

          assert_equal @field_cultivation.id, dto.field_cultivation[:id]
          assert_equal @field_cultivation.field_display_name, dto.field_cultivation[:field_name]
          assert_equal @farm.id, dto.farm[:id]
          assert_equal 1, dto.weather_data.length
          assert_equal 5.0, dto.gdd_data.first[:gdd]
          assert_equal progress_result, dto.progress_result
          assert dto.stages.any?
          assert_equal 0.0, dto.debug_info[:baseline_gdd]
          assert_equal true, dto.debug_info[:using_agrr_progress]
        end

        test "falls back to manual gdd when agrr progress returns no records" do
          start_date = @field_cultivation.start_date
          weather_data_cli = {
            "data" => [
              {
                "time" => start_date.to_s,
                "temperature_2m_max" => 25.0,
                "temperature_2m_min" => 15.0
              }
            ]
          }

          progress_result = {
            "progress_records" => []
          }

          progress_gateway = mock("AgrrProgressGateway")
          progress_gateway
            .expects(:calculate_progress)
            .with(
              crop: @crop,
              start_date: @field_cultivation.start_date,
              weather_data: weather_data_cli
            )
            .returns(progress_result)

          bundle = climate_bundle(use_mock_progress: false)
          bundle.fetch(:weather_gateway).stubs(:fetch_primary_weather_payload).returns(weather_data_cli)
          CompositionRoot.stubs(:agrr_progress_gateway).returns(progress_gateway)

          dto = assemble_climate_dto(bundle, field_cultivation_id: @field_cultivation.id)

          assert_equal false, dto.debug_info[:using_agrr_progress]
          assert_equal 0, dto.debug_info[:progress_records_count]
          assert_equal 1, dto.gdd_data.length
          assert_equal 12.0, dto.gdd_data.first[:gdd]
          assert_equal 20.0, dto.gdd_data.first[:temperature]
        end

        test "raises record not found when field cultivation missing" do
          bundle = climate_bundle(use_mock_progress: false)

          assert_raises(Domain::Shared::Exceptions::RecordNotFound) do
            bundle.fetch(:context_gateway).load_context(field_cultivation_id: 999_999)
          end
        end

        test "coerce_to_optional_date normalizes API query strings to Date" do
          gateway = CompositionRoot.field_cultivation_climate_weather_gateway

          d = Date.new(2024, 6, 1)
          assert_equal d, gateway.send(:coerce_to_optional_date, d)
          assert_equal d, gateway.send(:coerce_to_optional_date, "2024-06-01")
          assert_nil gateway.send(:coerce_to_optional_date, nil)
          assert_nil gateway.send(:coerce_to_optional_date, "")
          assert_nil gateway.send(:coerce_to_optional_date, "not-a-date")
        end
      end
    end
  end
end
