# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module WeatherData
    module Interactors
      class InternalFarmWeatherStatusInteractorTest < DomainLibTestCase
        setup do
          @gateway = mock("internal_farm_weather_read_gateway")
          @presenter = mock("presenter")
          @translator = mock("translator")
          @interactor = InternalFarmWeatherStatusInteractor.new(
            output_port: @presenter,
            gateway: @gateway,
            translator: @translator
          )
          @input_dto = Dtos::InternalFarmWeatherReadInput.new(farm_id: "99")
        end

        test "farm_not_found delegates translated message and not_found status" do
          @gateway.expects(:weather_status_snapshot).with(farm_id: "99").returns(
            Dtos::InternalFarmWeatherStatusResult.farm_not_found
          )
          @translator.expects(:t).with("api.errors.common.farm_not_found").returns("農場がありません")
          @presenter.expects(:on_failure).with do |dto|
            dto.is_a?(Dtos::InternalWeatherFetchFailure) &&
              dto.message == "農場がありません" &&
              dto.http_status == :not_found
          end

          @interactor.call(@input_dto)
        end

        test "ok maps status snapshot to on_success" do
          success = Dtos::InternalFarmWeatherStatusOutput.new(
            farm_id: 99,
            status: "completed",
            progress: 100,
            fetched_blocks: 5,
            total_blocks: 5,
            weather_data_count: 120,
            last_error: nil
          )
          @gateway.expects(:weather_status_snapshot).with(farm_id: "99").returns(
            Dtos::InternalFarmWeatherStatusResult.ok(success)
          )
          @presenter.expects(:on_success).with(success)

          @interactor.call(@input_dto)
        end
      end
    end
  end
end
