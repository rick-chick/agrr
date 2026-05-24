# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module WeatherData
    module Interactors
      class FetchWeatherDataRetryOnInteractorTest < DomainLibTestCase
        setup do
          @input_dto = {
            farm_id: 1,
            start_date: Date.new(2025, 1, 1),
            end_date: Date.new(2025, 1, 7),
            executions: 5,
            error_message: "API error"
          }
          @farm_gateway = mock("farm_gateway")
          @presenter = mock("presenter")
          @translator = mock("translator")
          @mark_failed = mock("mark_farm_weather_data_failed_interactor")
          @interactor = FetchWeatherDataRetryOnInteractor.new(
            farm_gateway: @farm_gateway,
            presenter: @presenter,
            advance_phase_interactor: mock("advance_phase_interactor"),
            mark_farm_weather_data_failed_interactor: @mark_failed,
            logger: CapturingLogger.new,
            translator: @translator
          )
        end

        test "execute calls presenter and marks failed" do
          @presenter.expects(:error).with(regexp_matches(/Failed to fetch.*after 5 attempts/))
          @presenter.expects(:error).with(regexp_matches(/Final error: API error/))
          @translator.expects(:t).with("jobs.fetch_weather_data.retry_limit_exceeded", error: "API error").returns("リトライ上限に達しました: API error")
          @mark_failed.expects(:call)

          @interactor.call(input_dto: @input_dto)
        end
      end
    end
  end
end
