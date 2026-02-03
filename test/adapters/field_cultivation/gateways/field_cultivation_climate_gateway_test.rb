# frozen_string_literal: true

require "test_helper"

module Adapters
  module FieldCultivation
    module Gateways
      class FieldCultivationClimateGatewayTest < ActiveSupport::TestCase
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

        test "returns climate dto for authorized field cultivation" do
          start_date = @field_cultivation.start_date
          weather_data_cli = {
            'data' => [
              {
                'time' => start_date.to_s,
                'temperature_2m_max' => 25.0,
                'temperature_2m_min' => 15.0,
                'temperature_2m_mean' => 20.0
              }
            ]
          }

          progress_result = {
            'progress_records' => [
              { 'date' => start_date.to_s, 'cumulative_gdd' => 5.0, 'stage_name' => 'Stage 1' }
            ]
          }

          weather_service = mock('WeatherPredictionService')
          weather_service
            .expects(:predict_for_cultivation_plan)
            .with(@plan)
            .returns({ data: weather_data_cli })

          progress_gateway = mock('AgrrProgressGateway')
          progress_gateway
            .expects(:calculate_progress)
            .with(
              crop: @crop,
              start_date: @field_cultivation.start_date,
              weather_data: weather_data_cli
            )
            .returns(progress_result)

          gateway = FieldCultivationClimateGateway.new(
            current_user: @user,
            use_mock_progress: false,
            progress_gateway_factory: -> { progress_gateway },
            weather_prediction_service_factory: ->(weather_location, farm) { weather_service }
          )

          dto = gateway.fetch_field_cultivation_climate_data(field_cultivation_id: @field_cultivation.id)

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
            'data' => [
              {
                'time' => start_date.to_s,
                'temperature_2m_max' => 25.0,
                'temperature_2m_min' => 15.0
              }
            ]
          }

          progress_result = {
            'progress_records' => []
          }

          weather_service = mock('WeatherPredictionService')
          weather_service
            .expects(:predict_for_cultivation_plan)
            .with(@plan)
            .returns({ data: weather_data_cli })

          progress_gateway = mock('AgrrProgressGateway')
          progress_gateway
            .expects(:calculate_progress)
            .with(
              crop: @crop,
              start_date: @field_cultivation.start_date,
              weather_data: weather_data_cli
            )
            .returns(progress_result)

          gateway = FieldCultivationClimateGateway.new(
            current_user: @user,
            use_mock_progress: false,
            progress_gateway_factory: -> { progress_gateway },
            weather_prediction_service_factory: ->(weather_location, farm) { weather_service }
          )

          dto = gateway.fetch_field_cultivation_climate_data(field_cultivation_id: @field_cultivation.id)

          assert_equal false, dto.debug_info[:using_agrr_progress]
          assert_equal 0, dto.debug_info[:progress_records_count]
          assert_equal 1, dto.gdd_data.length
          assert_equal 12.0, dto.gdd_data.first[:gdd]
          assert_equal 20.0, dto.gdd_data.first[:temperature]
        end

        test "raises record not found when field cultivation missing" do
          gateway = FieldCultivationClimateGateway.new(current_user: @user)

          assert_raises(ActiveRecord::RecordNotFound) do
            gateway.fetch_field_cultivation_climate_data(field_cultivation_id: 999_999)
          end
        end
      end
    end
  end
end
