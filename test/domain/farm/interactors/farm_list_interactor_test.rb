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
            user_id: @user_id
          )
        end

        test "should call gateway.list with input_dto and output_port.on_success on success for regular user" do
          filtered_farms = [
            Domain::Farm::Entities::FarmEntity.from_hash(
              id: 2,
              name: "User Farm",
              latitude: 36.0,
              longitude: 136.0,
              region: "Kyoto",
              user_id: @user_id,
              created_at: Time.current,
              updated_at: Time.current,
              is_reference: false
            )
          ]

          input_dto = Domain::Farm::Dtos::FarmListInputDto.new(is_admin: false)
          @mock_gateway.expects(:list).with(input_dto).returns(filtered_farms)
          @mock_output_port.expects(:on_success).with(filtered_farms)

          @interactor.call(input_dto)
        end

        test "should include reference farms for admin user" do
          admin_user = create(:user, admin: true)
          admin_user_id = admin_user.id
          admin_interactor = FarmListInteractor.new(
            output_port: @mock_output_port,
            gateway: @mock_gateway,
            user_id: admin_user_id
          )

          all_farms = [
            Domain::Farm::Entities::FarmEntity.from_hash(
              id: 1,
              name: "Reference Farm",
              latitude: 35.0,
              longitude: 135.0,
              region: "Kyoto",
              user_id: nil,
              created_at: Time.current,
              updated_at: Time.current,
              is_reference: true
            ),
            Domain::Farm::Entities::FarmEntity.from_hash(
              id: 2,
              name: "User Farm",
              latitude: 36.0,
              longitude: 136.0,
              region: "Kyoto",
              user_id: admin_user_id,
              created_at: Time.current,
              updated_at: Time.current,
              is_reference: false
            )
          ]

          input_dto = Domain::Farm::Dtos::FarmListInputDto.new(is_admin: true)
          @mock_gateway.expects(:list).with(input_dto).returns(all_farms)
          @mock_output_port.expects(:on_success).with(all_farms)

          admin_interactor.call(input_dto)
        end

      end
    end
  end
end