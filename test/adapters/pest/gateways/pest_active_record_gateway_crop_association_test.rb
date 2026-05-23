# frozen_string_literal: true

require "test_helper"

module Adapters
  module Pest
    module Gateways
      class PestActiveRecordGatewayCropAssociationTest < ActiveSupport::TestCase
        setup do
          @user = create(:user)
          @pest = create(:pest, is_reference: false, user: @user)
          @crop1 = create(:crop, is_reference: false, user: @user)
          @crop2 = create(:crop, is_reference: false, user: @user)
          @other_user_crop = create(:crop, is_reference: false, user: create(:user))
          @gw = PestActiveRecordGateway.new(deletion_undo_gateway: CompositionRoot.deletion_undo_gateway)
        end

        test "associate_crops_with_pest_id associates accessible crops" do
          count = @gw.associate_crops_with_pest_id(pest_id: @pest.id, crop_ids: [ @crop1.id, @crop2.id ], user: @user)

          assert_equal 2, count
          @pest.reload
          assert_includes @pest.crops, @crop1
          assert_includes @pest.crops, @crop2
        end

        test "associate_crops_with_pest_id does not associate inaccessible crops" do
          count = @gw.associate_crops_with_pest_id(pest_id: @pest.id, crop_ids: [ @crop1.id, @other_user_crop.id ], user: @user)

          assert_equal 1, count
          @pest.reload
          assert_includes @pest.crops, @crop1
          assert_not_includes @pest.crops, @other_user_crop
        end

        test "associate_crops_with_pest_id does not duplicate existing associations" do
          @pest.crops << @crop1

          count = @gw.associate_crops_with_pest_id(pest_id: @pest.id, crop_ids: [ @crop1.id, @crop2.id ], user: @user)

          assert_equal 1, count
          @pest.reload
          assert_equal 2, @pest.crops.count
        end

        test "update_pest_crop_associations adds new associations and removes old ones" do
          @pest.crops << @crop1

          result = @gw.update_pest_crop_associations(pest_id: @pest.id, crop_ids: [ @crop2.id ], user: @user)

          assert_equal 1, result[:added]
          assert_equal 1, result[:removed]
          @pest.reload
          assert_not_includes @pest.crops, @crop1
          assert_includes @pest.crops, @crop2
        end

        test "link_pest_to_crop links when crop is accessible per PestCropAssociationAccess" do
          status = @gw.link_pest_to_crop(
            crop_id: @crop1.id,
            pest_id: @pest.id,
            user: @user
          )

          assert_equal :linked, status
          assert_includes @crop1.reload.pests, @pest
        end

        test "pest_master_form_crop_selection_bundle! returns CropEntity cards without ActiveRecord in bundle" do
          payload = Domain::Pest::Dtos::PestMasterEditPayload.for_blank_new
          bundle = @gw.pest_master_form_crop_selection_bundle!(
            user: @user,
            master_edit_payload: payload,
            request_crop_ids: [ @crop1.id, @other_user_crop.id ]
          )

          assert_includes bundle.selected_crop_ids, @crop1.id
          assert_not_includes bundle.selected_crop_ids, @other_user_crop.id
          assert bundle.crop_cards.any?
          bundle.crop_cards.each do |card|
            assert_instance_of Domain::Crop::Entities::CropEntity, card[:crop]
            refute card[:crop].is_a?(::Crop)
          end
        end
      end
    end
  end
end
