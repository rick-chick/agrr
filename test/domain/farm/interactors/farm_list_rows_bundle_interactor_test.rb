# frozen_string_literal: true

require "test_helper"

module Domain
  module Farm
    module Interactors
      class FarmListRowsBundleInteractorTest < ActiveSupport::TestCase
        setup do
          @user = create(:user)
          @user_id = @user.id
          @mock_gateway = mock
          @mock_output_port = mock
          @interactor = FarmListRowsBundleInteractor.new(
            output_port: @mock_output_port,
            gateway: @mock_gateway,
            user_id: @user_id
          )
        end

        test "calls gateway.farm_list_rows_bundle and on_success with DTO" do
          input_dto = Domain::Farm::Dtos::FarmListInputDto.new(is_admin: false)
          row = Domain::Farm::Dtos::FarmListRowDto.new(
            id: 1,
            display_name: "A",
            latitude: 35.0,
            longitude: 135.0,
            region: "jp",
            user_id: @user_id,
            is_reference: false,
            field_count: 0,
            weather_data_status: "pending",
            weather_data_progress: 0,
            weather_data_total_years: 0,
            weather_data_status_text: "x",
            weather_data_last_error: nil
          )
          bundle = Domain::Farm::Dtos::FarmListRowsBundleDto.new(
            farm_rows: [ row ],
            reference_farm_rows: []
          )

          @mock_gateway.expects(:user_id=).with(@user_id).at_least_once
          @mock_gateway.expects(:farm_list_rows_bundle).with(input_dto).returns(bundle)

          @mock_output_port.expects(:on_success).with(bundle)

          @interactor.call(input_dto)
        end

        test "forwards policy permission denied to on_failure as exception" do
          err = Domain::Shared::Policies::PolicyPermissionDenied.new
          input_dto = Domain::Farm::Dtos::FarmListInputDto.new(is_admin: false)

          @mock_gateway.expects(:user_id=).with(@user_id).at_least_once
          @mock_gateway.expects(:farm_list_rows_bundle).with(input_dto).raises(err)
          @mock_output_port.expects(:on_failure).with(err)

          @interactor.call(input_dto)
        end
      end
    end
  end
end
