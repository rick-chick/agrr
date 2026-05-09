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

        test "normalize_crop_ids_for_pest_form filters to accessible crop IDs only" do
          normalized = @gw.normalize_crop_ids_for_pest_form(
            pest_model: @pest,
            raw_crop_ids: [ @crop1.id, @other_user_crop.id, 99999 ],
            user: @user
          )

          assert_includes normalized, @crop1.id
          assert_not_includes normalized, @other_user_crop.id
          assert_not_includes normalized, 99999
        end

        test "normalize_crop_ids_for_pest_form handles string IDs" do
          normalized = @gw.normalize_crop_ids_for_pest_form(
            pest_model: @pest,
            raw_crop_ids: [ @crop1.id.to_s, @crop2.id.to_s ],
            user: @user
          )

          assert_includes normalized, @crop1.id
          assert_includes normalized, @crop2.id
        end
      end
    end
  end
end
