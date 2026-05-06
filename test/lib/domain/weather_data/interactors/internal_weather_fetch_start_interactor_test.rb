# frozen_string_literal: true

require "test_helper"

module Domain
  module WeatherData
    module Interactors
      class InternalWeatherFetchStartInteractorTest < ActiveSupport::TestCase
        setup do
          @gateway = mock("internal_weather_fetch_gateway")
          @presenter = mock("presenter")
          @translator = mock("translator")
          @interactor = InternalWeatherFetchStartInteractor.new(
            output_port: @presenter,
            gateway: @gateway,
            translator: @translator
          )
          @input_dto = Dtos::InternalWeatherFetchStartInputDto.new(farm_id: "42")
        end

        test "farm_not_found delegates translated message and not_found status" do
          @gateway.expects(:start_internal_weather_data_fetch).with(farm_id: "42").returns(
            Gateways::InternalWeatherFetchStartGateway::StartInternalWeatherFetchResult.farm_not_found
          )
          @translator.expects(:t).with("api.errors.common.farm_not_found").returns("農場がありません")
          @presenter.expects(:on_failure).with do |dto|
            dto.is_a?(Dtos::InternalWeatherFetchFailureDto) &&
              dto.message == "農場がありません" &&
              dto.http_status == :not_found
          end

          @interactor.call(@input_dto)
        end

        test "completed maps snapshot to success dto" do
          snap = Gateways::InternalWeatherFetchStartGateway::WeatherFetchFarmSnapshot.new(
            farm_id: 42,
            weather_data_status: "completed",
            weather_data_count: 3,
            total_blocks: 10
          )
          @gateway.expects(:start_internal_weather_data_fetch).with(farm_id: "42").returns(
            Gateways::InternalWeatherFetchStartGateway::StartInternalWeatherFetchResult.completed(snap)
          )
          @presenter.expects(:on_success).with do |dto|
            dto.is_a?(Dtos::InternalWeatherFetchStartSuccessDto) &&
              dto.variant == Dtos::InternalWeatherFetchStartSuccessDto::VARIANT_ALREADY_COMPLETED &&
              dto.farm_id == 42 &&
              dto.weather_data_status == "completed" &&
              dto.weather_data_count == 3 &&
              dto.total_blocks == 10
          end

          @interactor.call(@input_dto)
        end

        test "started maps snapshot to success dto" do
          snap = Gateways::InternalWeatherFetchStartGateway::WeatherFetchFarmSnapshot.new(
            farm_id: 42,
            weather_data_status: "pending",
            weather_data_count: nil,
            total_blocks: 5
          )
          @gateway.expects(:start_internal_weather_data_fetch).with(farm_id: "42").returns(
            Gateways::InternalWeatherFetchStartGateway::StartInternalWeatherFetchResult.started(snap)
          )
          @presenter.expects(:on_success).with do |dto|
            dto.is_a?(Dtos::InternalWeatherFetchStartSuccessDto) &&
              dto.variant == Dtos::InternalWeatherFetchStartSuccessDto::VARIANT_FETCH_STARTED &&
              dto.farm_id == 42 &&
              dto.weather_data_status == "pending" &&
              dto.weather_data_count.nil? &&
              dto.total_blocks == 5
          end

          @interactor.call(@input_dto)
        end

        test "failed maps error message to internal_server_error" do
          @gateway.expects(:start_internal_weather_data_fetch).with(farm_id: "42").returns(
            Gateways::InternalWeatherFetchStartGateway::StartInternalWeatherFetchResult.failed("enqueue blew up")
          )
          @presenter.expects(:on_failure).with do |dto|
            dto.is_a?(Dtos::InternalWeatherFetchFailureDto) &&
              dto.message == "enqueue blew up" &&
              dto.http_status == :internal_server_error
          end

          @interactor.call(@input_dto)
        end
      end
    end
  end
end
