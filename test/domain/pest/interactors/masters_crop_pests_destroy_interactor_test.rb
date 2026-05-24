# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Pest
    module Interactors
      class MastersCropPestsDestroyInteractorTest < DomainLibTestCase
        setup do
          @user = domain_user_stub(id: 1, admin: false)
          @user_id = @user.id
          @mock_pest_gateway = mock
          @mock_crop_gateway = mock
          @mock_crop_pest_gateway = mock
          @mock_output_port = mock
          @mock_user_lookup = mock
          @crop_id = 100
          @pest_id = 7
          @interactor = MastersCropPestsDestroyInteractor.new(
            output_port: @mock_output_port,
            user_id: @user_id,
            user_lookup: @mock_user_lookup,
            pest_gateway: @mock_pest_gateway,
            crop_gateway: @mock_crop_gateway,
            crop_pest_gateway: @mock_crop_pest_gateway
          )
        end

        test "calls on_not_associated when association is missing" do
          crop_entity = Domain::Crop::Entities::CropEntity.new(
            id: @crop_id,
            user_id: @user_id,
            name: "トマト",
            variety: nil,
            is_reference: false,
            region: nil
          )
          pest_entity = Domain::Pest::Entities::PestEntity.new(
            id: @pest_id,
            user_id: @user_id,
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

          @mock_user_lookup.expects(:find).with(@user_id).returns(@user)
          @mock_crop_gateway.expects(:find_by_id).with(@crop_id).returns(crop_entity)
          @mock_pest_gateway.expects(:find_by_id).with(@pest_id).returns(pest_entity)
          @mock_crop_pest_gateway.expects(:find_by_crop_id_and_pest_id).with(crop_id: @crop_id, pest_id: @pest_id).returns(nil)
          @mock_crop_pest_gateway.expects(:delete).never
          @mock_output_port.expects(:on_not_associated).once

          @interactor.call(crop_id: @crop_id, pest_id: @pest_id)
        end

        test "calls on_success when association exists and delete succeeds" do
          crop_entity = Domain::Crop::Entities::CropEntity.new(
            id: @crop_id,
            user_id: @user_id,
            name: "トマト",
            variety: nil,
            is_reference: false,
            region: nil
          )
          pest_entity = Domain::Pest::Entities::PestEntity.new(
            id: @pest_id,
            user_id: @user_id,
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

          @mock_user_lookup.expects(:find).with(@user_id).returns(@user)
          @mock_crop_gateway.expects(:find_by_id).with(@crop_id).returns(crop_entity)
          @mock_pest_gateway.expects(:find_by_id).with(@pest_id).returns(pest_entity)
          link = Domain::Pest::Entities::CropPestLinkEntity.new(id: 1, crop_id: @crop_id, pest_id: @pest_id)
          @mock_crop_pest_gateway.expects(:find_by_crop_id_and_pest_id).with(crop_id: @crop_id, pest_id: @pest_id).returns(link)
          @mock_crop_pest_gateway.expects(:delete).with(crop_id: @crop_id, pest_id: @pest_id).returns(true)
          @mock_output_port.expects(:on_success).once

          @interactor.call(crop_id: @crop_id, pest_id: @pest_id)
        end
      end
    end
  end
end
