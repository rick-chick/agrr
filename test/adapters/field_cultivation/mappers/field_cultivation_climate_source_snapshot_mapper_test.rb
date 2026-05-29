# frozen_string_literal: true

require "test_helper"

module Adapters
  module FieldCultivation
    module Mappers
      class FieldCultivationClimateSourceSnapshotMapperTest < ActiveSupport::TestCase
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
          @preloaded = Gateways::FieldCultivationClimatePreload.find!(
            field_cultivation_id: @field_cultivation.id
          )
        end

        test "plan_access_snapshot_from_model maps plan type and owner from AR" do
          access = FieldCultivationClimateSourceSnapshotMapper.plan_access_snapshot_from_model(@preloaded)

          assert_equal @field_cultivation.id, access.field_cultivation_id
          refute access.plan_type_public
          assert access.plan_type_private
          assert_equal @user.id, access.plan_user_id
        end

        test "climate_source_snapshot_from_model maps farm weather and crop from AR" do
          source = FieldCultivationClimateSourceSnapshotMapper.climate_source_snapshot_from_model(@preloaded)

          assert_equal @field_cultivation.id, source.field_cultivation_id
          assert_equal @farm.weather_location.id, source.weather_location_id
          assert_equal @crop.id, source.plan_crop_crop_id
          assert_equal @field_cultivation.field_display_name, source.field_name
        end
      end
    end
  end
end
