# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Farm
    module Interactors
      class MarkFarmWeatherDataFailedInteractorTest < DomainLibTestCase
        setup do
          @farm_gateway = mock("farm_gateway")
          @interactor = MarkFarmWeatherDataFailedInteractor.new(farm_gateway: @farm_gateway)
          @input = Dtos::MarkFarmWeatherDataFailedInput.new(
            farm_id: 7,
            error_message: "daemon timeout"
          )
        end

        test "persists failed status and error message via gateway" do
          expected_attrs = Calculators::FarmWeatherProgressCalculator.failed_attrs(
            error_message: "daemon timeout"
          )
          updated = Object.new
          @farm_gateway.expects(:update_weather_progress).with(7, expected_attrs).returns(updated)

          assert_equal updated, @interactor.call(@input)
        end
      end
    end
  end
end
