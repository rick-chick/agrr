# frozen_string_literal: true

require "test_helper"

module Adapters
  module Pest
    module Gateways
      class CropPestActiveRecordGatewayTest < ActiveSupport::TestCase
        setup do
          @user = create(:user)
          @pest = create(:pest, is_reference: false, user: @user)
          @crop1 = create(:crop, is_reference: false, user: @user)
          @crop2 = create(:crop, is_reference: false, user: @user)
          @gw = CropPestActiveRecordGateway.new
        end

        test "create links crop and pest" do
          @gw.create(crop_id: @crop1.id, pest_id: @pest.id)

          assert_includes @crop1.reload.pests, @pest
        end

        test "find_by_crop_id_and_pest_id returns link entity when present" do
          @gw.create(crop_id: @crop1.id, pest_id: @pest.id)

          link = @gw.find_by_crop_id_and_pest_id(crop_id: @crop1.id, pest_id: @pest.id)

          assert_instance_of Domain::Pest::Entities::CropPestLinkEntity, link
          assert_equal @crop1.id, link.crop_id
          assert_equal @pest.id, link.pest_id
        end

        test "list_by_pest_id returns linked crop ids" do
          @gw.create(crop_id: @crop1.id, pest_id: @pest.id)
          @gw.create(crop_id: @crop2.id, pest_id: @pest.id)

          assert_equal [ @crop1.id, @crop2.id ].sort, @gw.list_by_pest_id(pest_id: @pest.id).sort
        end

        test "delete removes association" do
          @gw.create(crop_id: @crop1.id, pest_id: @pest.id)

          assert @gw.delete(crop_id: @crop1.id, pest_id: @pest.id)
          assert_nil @gw.find_by_crop_id_and_pest_id(crop_id: @crop1.id, pest_id: @pest.id)
        end

        test "replace via PestUpdateCropAssociationsInteractor adds and removes rows" do
          @gw.create(crop_id: @crop1.id, pest_id: @pest.id)

          result = Domain::Pest::Interactors::PestUpdateCropAssociationsInteractor.new(crop_pest_gateway: @gw)
            .call(pest_id: @pest.id, crop_ids: [ @crop2.id ])

          assert_equal 1, result.added
          assert_equal 1, result.removed
          @pest.reload
          assert_not_includes @pest.crops, @crop1
          assert_includes @pest.crops, @crop2
        end
      end
    end
  end
end
