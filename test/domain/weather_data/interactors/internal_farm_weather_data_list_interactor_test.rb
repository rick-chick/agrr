# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module WeatherData
    module Interactors
      class InternalFarmWeatherDataListInteractorTest < DomainLibTestCase
        setup do
          @gateway = mock("internal_farm_weather_read_gateway")
          @presenter = mock("presenter")
          @translator = mock("translator")
          @interactor = InternalFarmWeatherDataListInteractor.new(
            output_port: @presenter,
            gateway: @gateway,
            translator: @translator
          )
          @input_dto = Dtos::InternalFarmWeatherReadInput.new(farm_id: "42")
        end

        test "farm_not_found delegates translated message and not_found status" do
          @gateway.expects(:weather_data_list_snapshot).with(farm_id: "42").returns(
            Dtos::InternalFarmWeatherDataListResult.farm_not_found
          )
          @translator.expects(:t).with("api.errors.common.farm_not_found").returns("農場がありません")
          @presenter.expects(:on_failure).with do |dto|
            dto.is_a?(Dtos::InternalWeatherFetchFailure) &&
              dto.message == "農場がありません" &&
              dto.http_status == :not_found
          end

          @interactor.call(@input_dto)
        end

        test "weather_location_not_found delegates translated message" do
          @gateway.expects(:weather_data_list_snapshot).with(farm_id: "42").returns(
            Dtos::InternalFarmWeatherDataListResult.weather_location_not_found
          )
          @translator.expects(:t).with("api.errors.common.weather_location_not_found").returns("気象地点がありません")
          @presenter.expects(:on_failure).with do |dto|
            dto.is_a?(Dtos::InternalWeatherFetchFailure) &&
              dto.message == "気象地点がありません" &&
              dto.http_status == :not_found
          end

          @interactor.call(@input_dto)
        end

        test "ok maps success dto to on_success" do
          success = Dtos::InternalFarmWeatherDataListOutput.new(
            farm_summary: { id: 42 },
            weather_location_summary: { id: 1 },
            weather_data_rows: [],
            count: 0
          )
          @gateway.expects(:weather_data_list_snapshot).with(farm_id: "42").returns(
            Dtos::InternalFarmWeatherDataListResult.ok(success)
          )
          @presenter.expects(:on_success).with(success)

          @interactor.call(@input_dto)
        end
      end
    end
  end
end
