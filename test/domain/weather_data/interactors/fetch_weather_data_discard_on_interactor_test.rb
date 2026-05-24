# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module WeatherData
    module Interactors
      class FetchWeatherDataDiscardOnInteractorTest < DomainLibTestCase
        setup do
          @input_dto = {
            farm_id: 1,
            start_date: Date.new(2025, 1, 1),
            end_date: Date.new(2025, 1, 7),
            error_message: "Invalid record"
          }
          @farm_gateway = mock("farm_gateway")
          @presenter = mock("presenter")
          @translator = mock("translator")
          @mark_failed = mock("mark_farm_weather_data_failed_interactor")
          @interactor = FetchWeatherDataDiscardOnInteractor.new(
            farm_gateway: @farm_gateway,
            presenter: @presenter,
            logger: CapturingLogger.new,
            translator: @translator,
            mark_farm_weather_data_failed_interactor: @mark_failed
          )
        end

        test "execute calls presenter and marks failed" do
          @presenter.expects(:error).with(regexp_matches(/Invalid data.*Invalid record/))
          @translator.expects(:t).with("jobs.fetch_weather_data.validation_error", error: "Invalid record").returns("データ検証エラー: Invalid record")
          @mark_failed.expects(:call)

          @interactor.call(input_dto: @input_dto)
        end
      end
    end
  end
end
