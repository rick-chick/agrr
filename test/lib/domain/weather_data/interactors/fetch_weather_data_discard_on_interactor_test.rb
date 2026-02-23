# frozen_string_literal: true

require 'test_helper'

module Domain
  module WeatherData
    module Interactors
      class FetchWeatherDataDiscardOnInteractorTest < ActiveSupport::TestCase
        setup do
          @input_dto = {
            farm_id: 1,
            start_date: Date.new(2025, 1, 1),
            end_date: Date.new(2025, 1, 7),
            error_message: 'Invalid record'
          }
          @farm_gateway = mock('farm_gateway')
          @presenter = mock('presenter')
          @translator = mock('translator')
          @interactor = FetchWeatherDataDiscardOnInteractor.new(
            farm_gateway: @farm_gateway,
            presenter: @presenter,
            logger: Adapters::Logger::Gateways::RailsLoggerGateway.new,
            translator: @translator
          )
        end

        test 'execute calls presenter and marks failed' do
          @presenter.expects(:error).with(regexp_matches(/Invalid data.*Invalid record/))
          @translator.expects(:t).with('jobs.fetch_weather_data.validation_error', error: 'Invalid record').returns('データ検証エラー: Invalid record')
          @farm_gateway.expects(:mark_weather_data_failed).with(1, 'データ検証エラー: Invalid record')

          @interactor.execute(input_dto: @input_dto)
        end
      end
    end
  end
end
