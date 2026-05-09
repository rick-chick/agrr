# frozen_string_literal: true

require "test_helper"

module Domain
  module Pest
    module Interactors
      class MastersCropPestsCreateInteractorTest < ActiveSupport::TestCase
        setup do
          @user = create(:user)
          @user_id = @user.id
          @mock_pest_gateway = mock
          @mock_output_port = mock
          @mock_user_lookup = mock
          @crop_id = 100
          @pest_id = 7
          @interactor = MastersCropPestsCreateInteractor.new(
            output_port: @mock_output_port,
            user_id: @user_id,
            user_lookup: @mock_user_lookup,
            pest_gateway: @mock_pest_gateway
          )
        end

        test "calls on_pest_not_found when find_by_id raises RecordNotFound" do
          @mock_pest_gateway.expects(:find_by_id).with(@pest_id).raises(Domain::Shared::Exceptions::RecordNotFound)
          @mock_user_lookup.expects(:find).never
          @mock_output_port.expects(:on_pest_not_found).once

          @interactor.call(@crop_id, @pest_id)
        end

        test "calls on_success when pest is found, selectable, and link returns :linked" do
          pest_entity = Domain::Pest::Entities::PestEntity.new(
            id: @pest_id,
            name: "アブラムシ",
            name_scientific: nil,
            family: nil,
            order: nil,
            description: nil,
            occurrence_season: nil,
            region: nil,
            is_reference: false,
            created_at: nil,
            updated_at: nil
          )

          @mock_pest_gateway.expects(:find_by_id).with(@pest_id).returns(pest_entity)
          @mock_user_lookup.expects(:find).with(@user_id).returns(@user)
          @mock_pest_gateway.expects(:pest_selectable_by_user?).with(@user, @pest_id).returns(true)
          @mock_pest_gateway.expects(:link_pest_to_crop).with(
            crop_id: @crop_id,
            pest_id: @pest_id,
            crop_access_filter: instance_of(Domain::Shared::ReferenceRecordAccessFilter)
          ).returns(:linked)
          @mock_output_port.expects(:on_success).with(crop_id: @crop_id, pest_id: @pest_id)

          @interactor.call(@crop_id, @pest_id)
        end
      end
    end
  end
end
