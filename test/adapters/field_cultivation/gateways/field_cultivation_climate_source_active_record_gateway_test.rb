# frozen_string_literal: true

require "test_helper"

module Adapters
  module FieldCultivation
    module Gateways
      class FieldCultivationClimateSourceActiveRecordGatewayTest < ActiveSupport::TestCase
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

        def climate_source_gateway
          CompositionRoot.field_cultivation_climate_source_gateway_for
        end

        # show/update の HTTP 契約は controller テストが証明。adapter は AR → Snapshot / weather DTO の wire のみ。
        test "maps persisted field cultivation to plan access and climate source snapshots" do
          access = climate_source_gateway.find_plan_access_snapshot_by_field_cultivation_id(@field_cultivation.id)
          source = climate_source_gateway.find_climate_source_snapshot_by_field_cultivation_id(@field_cultivation.id)

          assert_instance_of Domain::FieldCultivation::Dtos::FieldCultivationPlanAccessSnapshot, access
          assert_equal @field_cultivation.id, access.field_cultivation_id
          refute access.plan_type_public
          assert_equal @user.id, access.plan_user_id

          assert_instance_of Domain::FieldCultivation::Dtos::FieldCultivationClimateSourceSnapshot, source
          assert_equal @field_cultivation.id, source.field_cultivation_id
          assert_equal @farm.weather_location.id, source.weather_location_id
          assert_equal @crop.id, source.plan_crop_crop_id
        end

        test "find_weather_prediction_targets_by_plan_id returns domain DTOs" do
          targets = climate_source_gateway.find_weather_prediction_targets_by_plan_id(@plan.id)

          assert_instance_of Domain::WeatherData::Dtos::WeatherPredictionTargets, targets
          assert_instance_of Domain::WeatherData::Dtos::WeatherLocation, targets.weather_location
          assert_instance_of Domain::WeatherData::Dtos::FarmWeatherPrediction, targets.farm
          assert_equal @farm.weather_location.id, targets.weather_location.id
          assert_equal @farm.id, targets.farm.id
        end

        test "raises record not found when field cultivation missing" do
          assert_raises(Domain::Shared::Exceptions::RecordNotFound) do
            climate_source_gateway.find_climate_source_snapshot_by_field_cultivation_id(999_999)
          end
        end
      end
    end
  end
end
