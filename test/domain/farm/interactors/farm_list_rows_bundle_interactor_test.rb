# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Farm
    module Interactors
      class FarmListRowsBundleInteractorTest < DomainLibTestCase
        setup do
          @user_id = 1
          @mock_gateway = mock
          @mock_output_port = mock
          @interactor = FarmListRowsBundleInteractor.new(
            output_port: @mock_output_port,
            gateway: @mock_gateway,
            user_id: @user_id
          )
        end

        def make_row(id:)
          Domain::Farm::Dtos::FarmListRow.new(
            id: id,
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
            weather_data_last_error: nil
          )
        end

        test "non-admin: lists owned farm rows only" do
          input_dto = Domain::Farm::Dtos::FarmListInput.new(is_admin: false)
          row = make_row(id: 1)

          @mock_gateway.expects(:user_id=).with(@user_id).at_least_once
          @mock_gateway.expects(:list_user_owned_farm_rows).with(user_id: @user_id).returns([ row ])
          @mock_output_port.expects(:on_success).with do |bundle|
            assert_equal [ row ], bundle.farm_rows
            assert_equal [], bundle.reference_farm_rows
            true
          end

          @interactor.call(input_dto)
        end

        test "admin: lists owned+reference rows and reference section" do
          admin_user_id = 2
          admin_interactor = FarmListRowsBundleInteractor.new(
            output_port: @mock_output_port,
            gateway: @mock_gateway,
            user_id: admin_user_id
          )
          input_dto = Domain::Farm::Dtos::FarmListInput.new(is_admin: true)
          farm_row = make_row(id: 1)
          ref_row = Domain::Farm::Dtos::FarmListRow.new(
            id: 2, display_name: "Ref", latitude: 35.0, longitude: 135.0, region: "jp",
            user_id: nil, is_reference: true, field_count: 0,
            weather_data_status: "pending", weather_data_progress: 0,
            weather_data_total_years: 0, weather_data_last_error: nil
          )

          @mock_gateway.expects(:user_id=).with(admin_user_id).at_least_once
          @mock_gateway.expects(:list_user_and_reference_farm_rows).with(user_id: admin_user_id).returns([ farm_row ])
          @mock_gateway.expects(:list_reference_farm_rows).returns([ ref_row ])
          @mock_output_port.expects(:on_success).with do |bundle|
            assert_equal [ farm_row ], bundle.farm_rows
            assert_equal [ ref_row ], bundle.reference_farm_rows
            true
          end

          admin_interactor.call(input_dto)
        end

        test "forwards policy permission denied to on_failure as exception" do
          err = Domain::Shared::Policies::PolicyPermissionDenied.new
          input_dto = Domain::Farm::Dtos::FarmListInput.new(is_admin: false)

          @mock_gateway.expects(:user_id=).with(@user_id).at_least_once
          @mock_gateway.expects(:list_user_owned_farm_rows).with(user_id: @user_id).raises(err)
          @mock_output_port.expects(:on_failure).with(err)

          @interactor.call(input_dto)
        end
      end
    end
  end
end
