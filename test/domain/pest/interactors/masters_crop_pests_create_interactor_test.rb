# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Pest
    module Interactors
      class MastersCropPestsCreateInteractorTest < DomainLibTestCase
        setup do
          @user = Object.new
          @user.define_singleton_method(:id) { 1 }
          @user.define_singleton_method(:email) { "test@example.com" }
          @user.define_singleton_method(:name) { "Test" }
          @user.define_singleton_method(:admin?) { false }
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

          crop_entity = Domain::Crop::Entities::CropEntity.new(
            id: @crop_id,
            user_id: @user_id,
            name: "トマト",
            variety: nil,
            is_reference: false,
            region: nil
          )

          @mock_pest_gateway.expects(:find_by_id).with(@pest_id).returns(pest_entity)
          @mock_user_lookup.expects(:find).with(@user_id).returns(@user)
          @mock_pest_gateway.expects(:pest_selectable_by_user?).with(@user, @pest_id).returns(true)
          @mock_pest_gateway.expects(:find_crop_entity_by_id).with(@crop_id).returns(crop_entity)
          @mock_pest_gateway.expects(:crop_pest_association_exists?).with(crop_id: @crop_id, pest_id: @pest_id).returns(false)
          @mock_pest_gateway.expects(:link_pest_to_crop).with(
            crop_id: @crop_id,
            pest_id: @pest_id,
            user: @user
          ).returns(:linked)
          @mock_output_port.expects(:on_success).with(crop_id: @crop_id, pest_id: @pest_id)

          @interactor.call(@crop_id, @pest_id)
        end

        test "calls on_already_associated when crop_pest_association_exists" do
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
          crop_entity = Domain::Crop::Entities::CropEntity.new(
            id: @crop_id,
            user_id: @user_id,
            name: "トマト",
            variety: nil,
            is_reference: false,
            region: nil
          )

          @mock_pest_gateway.expects(:find_by_id).with(@pest_id).returns(pest_entity)
          @mock_user_lookup.expects(:find).with(@user_id).returns(@user)
          @mock_pest_gateway.expects(:pest_selectable_by_user?).with(@user, @pest_id).returns(true)
          @mock_pest_gateway.expects(:find_crop_entity_by_id).with(@crop_id).returns(crop_entity)
          @mock_pest_gateway.expects(:crop_pest_association_exists?).with(crop_id: @crop_id, pest_id: @pest_id).returns(true)
          @mock_pest_gateway.expects(:link_pest_to_crop).never
          @mock_output_port.expects(:on_already_associated).once

          @interactor.call(@crop_id, @pest_id)
        end

        test "calls on_forbidden when crop is not associable with pest per PestCropAssociationAccess" do
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
          other_crop = Domain::Crop::Entities::CropEntity.new(
            id: @crop_id,
            user_id: 99,
            name: "他人の作物",
            variety: nil,
            is_reference: false,
            region: nil
          )

          @mock_pest_gateway.expects(:find_by_id).with(@pest_id).returns(pest_entity)
          @mock_user_lookup.expects(:find).with(@user_id).returns(@user)
          @mock_pest_gateway.expects(:pest_selectable_by_user?).with(@user, @pest_id).returns(true)
          @mock_pest_gateway.expects(:find_crop_entity_by_id).with(@crop_id).returns(other_crop)
          @mock_pest_gateway.expects(:link_pest_to_crop).never
          @mock_output_port.expects(:on_forbidden).once

          @interactor.call(@crop_id, @pest_id)
        end
      end
    end
  end
end
