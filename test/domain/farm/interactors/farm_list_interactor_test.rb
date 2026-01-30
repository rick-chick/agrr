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

        test "should call gateway.list and filter with visible_scope, then output_port.on_success on success for regular user" do
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
              user_id: @user_id,
              created_at: Time.current,
              updated_at: Time.current,
              is_reference: false
            ),
            Domain::Farm::Entities::FarmEntity.from_hash(
              id: 3,
              name: "Other User Farm",
              latitude: 37.0,
              longitude: 137.0,
              region: "Kyoto",
              user_id: @user_id + 1,
              created_at: Time.current,
              updated_at: Time.current,
              is_reference: false
            )
          ]

          # Mock User.find to return a user object
          user = mock
          User.expects(:find).with(@user_id).returns(user)

          # Mock the policy visible_scope to return a scope that includes farms with id 1 and 2
          visible_scope = mock
          Domain::Shared::Policies::FarmPolicy.expects(:visible_scope).with(::Farm, user).returns(visible_scope)
          visible_scope.expects(:exists?).with(1).returns(true)
          visible_scope.expects(:exists?).with(2).returns(true)
          visible_scope.expects(:exists?).with(3).returns(false)

          @mock_gateway.expects(:list).returns(all_farms)
          @mock_output_port.expects(:on_success).with([all_farms[0], all_farms[1]]) # reference and user's farm

          @interactor.call
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

          # Mock User.find to return admin user
          User.expects(:find).with(admin_user_id).returns(admin_user)

          # Mock the policy visible_scope and reference scope
          visible_scope = mock
          reference_scope = mock
          combined_scope = mock
          Domain::Shared::Policies::FarmPolicy.expects(:visible_scope).with(::Farm, admin_user).returns(visible_scope)
          ::Farm.expects(:reference).returns(reference_scope)
          visible_scope.expects(:or).with(reference_scope).returns(combined_scope)
          combined_scope.expects(:exists?).with(1).returns(true)
          combined_scope.expects(:exists?).with(2).returns(true)

          @mock_gateway.expects(:list).returns(all_farms)
          @mock_output_port.expects(:on_success).with(all_farms)

          input_dto = Domain::Farm::Dtos::FarmListInputDto.new(is_admin: true)
          admin_interactor.call(input_dto)
        end

      end
    end
  end
end