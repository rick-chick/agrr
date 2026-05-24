# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Pest
    module Interactors
      class PestLinkToCropInteractorTest < DomainLibTestCase
        setup do
          @pest_gateway = mock
          @crop_pest_gateway = mock
          @crop_gateway = mock
          @interactor = PestLinkToCropInteractor.new(
            pest_gateway: @pest_gateway,
            crop_pest_gateway: @crop_pest_gateway,
            crop_gateway: @crop_gateway
          )
        end

        test "returns :linked when crop and pest exist and association is new" do
          crop = Domain::Crop::Entities::CropEntity.new(
            id: 1, user_id: 2, name: "Tomato", variety: nil, is_reference: false, region: nil
          )
          pest = Domain::Pest::Entities::PestEntity.new(
            id: 3, user_id: 2, name: "Aphid", name_scientific: nil, family: nil, order: nil,
            description: nil, occurrence_season: nil, region: nil, is_reference: false,
            created_at: nil, updated_at: nil
          )

          @crop_gateway.expects(:find_by_id).with(1).returns(crop)
          @pest_gateway.expects(:find_by_id).with(3).returns(pest)
          @crop_pest_gateway.expects(:find_by_crop_id_and_pest_id).with(crop_id: 1, pest_id: 3).returns(nil)
          @crop_pest_gateway.expects(:create).with(crop_id: 1, pest_id: 3)

          assert_equal :linked, @interactor.call(crop_id: 1, pest_id: 3)
        end

        test "returns :already_linked when association exists" do
          crop = Domain::Crop::Entities::CropEntity.new(
            id: 1, user_id: 2, name: "Tomato", variety: nil, is_reference: false, region: nil
          )
          pest = Domain::Pest::Entities::PestEntity.new(
            id: 3, user_id: 2, name: "Aphid", name_scientific: nil, family: nil, order: nil,
            description: nil, occurrence_season: nil, region: nil, is_reference: false,
            created_at: nil, updated_at: nil
          )
          link = Entities::CropPestLinkEntity.new(id: 9, crop_id: 1, pest_id: 3)

          @crop_gateway.expects(:find_by_id).with(1).returns(crop)
          @pest_gateway.expects(:find_by_id).with(3).returns(pest)
          @crop_pest_gateway.expects(:find_by_crop_id_and_pest_id).with(crop_id: 1, pest_id: 3).returns(link)
          @crop_pest_gateway.expects(:create).never

          assert_equal :already_linked, @interactor.call(crop_id: 1, pest_id: 3)
        end
      end
    end
  end
end
