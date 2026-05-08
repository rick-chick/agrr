# frozen_string_literal: true

require "test_helper"

module Domain
  module Farm
    module Interactors
      class FarmListInteractorTest < ActiveSupport::TestCase
        setup do
          @user = create(:user)
          @user_id = @user.id
          @mock_gateway = mock
          @mock_output_port = mock
          @interactor = FarmListInteractor.new(
            output_port: @mock_output_port,
            gateway: @mock_gateway,
            user_id: @user_id,
            translator: Adapters::Translators::RailsTranslator.new
          )
        end

        test "calls gateway.list and on_success with reference_farms for regular user" do
          filtered_farms = [ Object.new ]
          input_dto = Domain::Farm::Dtos::FarmListInputDto.new(is_admin: false)
          @mock_gateway.expects(:user_id=).with(@user_id)
          @mock_gateway.expects(:list).with(input_dto).returns(filtered_farms)
          @mock_gateway.expects(:reference_farms_for_admin_list).with(is_admin: false).returns([])
          @mock_output_port.expects(:on_success).with(filtered_farms, reference_farms: [])

          @interactor.call(input_dto)
        end

        test "passes reference_farms from gateway to on_success for admin" do
          admin_user = create(:user, admin: true)
          admin_interactor = FarmListInteractor.new(
            output_port: @mock_output_port,
            gateway: @mock_gateway,
            user_id: admin_user.id,
            translator: Adapters::Translators::RailsTranslator.new
          )

          list_rows = [ Object.new ]
          ref_rows = [ Object.new ]
          input_dto = Domain::Farm::Dtos::FarmListInputDto.new(is_admin: true)
          @mock_gateway.expects(:user_id=).with(admin_user.id)
          @mock_gateway.expects(:list).with(input_dto).returns(list_rows)
          @mock_gateway.expects(:reference_farms_for_admin_list).with(is_admin: true).returns(ref_rows)
          @mock_output_port.expects(:on_success).with(list_rows, reference_farms: ref_rows)

          admin_interactor.call(input_dto)
        end

        test "forwards policy permission denied to on_failure as exception" do
          err = Domain::Shared::Policies::PolicyPermissionDenied.new
          input_dto = Domain::Farm::Dtos::FarmListInputDto.new(is_admin: false)
          @mock_gateway.expects(:user_id=).with(@user_id)
          @mock_gateway.expects(:list).with(input_dto).raises(err)
          @mock_output_port.expects(:on_failure).with(err)

          @interactor.call(input_dto)
        end
      end
    end
  end
end
