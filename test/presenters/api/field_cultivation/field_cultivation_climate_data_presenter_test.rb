# frozen_string_literal: true

require 'test_helper'
require_relative '../../../../app/presenters/api/field_cultivation_climate/field_cultivation_climate_data_presenter'

class FieldCultivationClimateDataPresenterTest < ActiveSupport::TestCase
  test 'on_success renders success payload with status ok' do
    view_mock = mock
    presenter = Api::FieldCultivationClimate::FieldCultivationClimateDataPresenter.new(view: view_mock)

    field_cultivation = {
      id: 1,
      field_name: '北区 北圃場',
      crop_name: 'トマト',
      start_date: '2026-02-01',
      completion_date: '2026-05-30'
    }
    farm = { id: 2, name: '横浜ファーム', latitude: 35.4, longitude: 139.6 }
    crop_requirements = {
      base_temperature: 12.0,
      optimal_temperature_range: {
        min: 18.0,
        max: 28.0,
        low_stress: 15.0,
        high_stress: 33.0
      }
    }
    weather_data = [
      {
        date: '2026-02-01',
        temperature_max: 20.5,
        temperature_min: 9.3,
        temperature_mean: 14.9
      }
    ]
    gdd_data = [
      {
        date: '2026-02-01',
        gdd: 2.9,
        cumulative_gdd: 2.9,
        temperature: 14.9,
        current_stage: '播種〜発芽'
      }
    ]
    stages = [
      {
        name: '播種〜発芽',
        order: 1,
        gdd_required: 75.0,
        cumulative_gdd_required: 75.0,
        optimal_temperature_min: 18.0,
        optimal_temperature_max: 28.0,
        low_stress_threshold: 15.0,
        high_stress_threshold: 33.0
      }
    ]
    progress_result = { 'progress_records' => [], 'total_gdd' => 0.0 }
    debug_info = {
      baseline_gdd: 0.0,
      progress_records_count: 0,
      filtered_records_count: 0,
      using_agrr_progress: false,
      sample_raw_data: []
    }
    success_dto = Domain::FieldCultivation::Dtos::FieldCultivationClimateDataSuccessDto.new(
      field_cultivation: field_cultivation,
      farm: farm,
      crop_requirements: crop_requirements,
      weather_data: weather_data,
      gdd_data: gdd_data,
      stages: stages,
      progress_result: progress_result,
      debug_info: debug_info
    )

    expected_json = {
      success: true,
      field_cultivation: field_cultivation,
      farm: farm,
      crop_requirements: crop_requirements,
      weather_data: weather_data,
      gdd_data: gdd_data,
      stages: stages,
      progress_result: progress_result,
      debug_info: debug_info
    }

    view_mock.expects(:render_response).with(
      json: expected_json,
      status: :ok
    )

    presenter.on_success(success_dto)
  end

  test 'on_failure renders not_found when message indicates missing data' do
    view_mock = mock
    presenter = Api::FieldCultivationClimate::FieldCultivationClimateDataPresenter.new(view: view_mock)

    error_message = 'Field cultivation climate data not found'
    failure_dto = Domain::Shared::Dtos::ErrorDto.new(error_message)

    view_mock.expects(:render_response).with(
      json: { success: false, message: error_message },
      status: :not_found
    )

    presenter.on_failure(failure_dto)
  end

  test 'on_failure renders bad_request for cultivation period missing errors' do
    view_mock = mock
    presenter = Api::FieldCultivationClimate::FieldCultivationClimateDataPresenter.new(view: view_mock)

    error_message = '栽培期間が設定されていません'
    failure_dto = Domain::Shared::Dtos::ErrorDto.new(error_message)

    view_mock.expects(:render_response).with(
      json: { success: false, message: error_message },
      status: :bad_request
    )

    presenter.on_failure(failure_dto)
  end

  test 'on_failure renders internal_server_error for unexpected errors' do
    view_mock = mock
    presenter = Api::FieldCultivationClimate::FieldCultivationClimateDataPresenter.new(view: view_mock)

    error_message = 'AGRR Progress calculation failed'
    failure_dto = Domain::Shared::Dtos::ErrorDto.new(error_message)

    view_mock.expects(:render_response).with(
      json: { success: false, message: error_message },
      status: :internal_server_error
    )

    presenter.on_failure(failure_dto)
  end
end
