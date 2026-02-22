# frozen_string_literal: true

require 'test_helper'

module Domain
  module WeatherData
    module Interactors
      class FetchWeatherDataRetryOnInteractorTest < ActiveSupport::TestCase
        setup do
          @input_dto = {
            farm_id: 1,
            start_date: Date.new(2025, 1, 1),
            end_date: Date.new(2025, 1, 7),
            executions: 5,
            error_message: 'API error'
          }
          @farm_gateway = mock('farm_gateway')
          @presenter = mock('presenter')
          @translator = mock('translator')
          @interactor = FetchWeatherDataRetryOnInteractor.new(
            farm_gateway: @farm_gateway,
            presenter: @presenter,
            cultivation_plan_gateway: mock('cultivation_plan_gateway'),
            translator: @translator
          )
        end

        test 'execute calls presenter and marks failed' do
          @presenter.expects(:error).with(regexp_matches(/Failed to fetch.*after 5 attempts/))
          @presenter.expects(:error).with(regexp_matches(/Final error: API error/))
          @translator.expects(:t).with('jobs.fetch_weather_data.retry_limit_exceeded', error: 'API error').returns('リトライ上限に達しました: API error')
          @farm_gateway.expects(:mark_weather_data_failed).with(1, 'リトライ上限に達しました: API error')

          @interactor.execute(input_dto: @input_dto)
        end
      end
    end
  end
end
