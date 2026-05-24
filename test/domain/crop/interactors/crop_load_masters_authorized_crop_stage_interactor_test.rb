# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Crop
    module Interactors
      class CropLoadMastersAuthorizedCropStageInteractorTest < DomainLibTestCase
        test "returns bundle when crop and stage match" do
          crop_entity = Domain::Crop::Entities::CropEntity.new(
            id: 1, user_id: 1, name: "x", variety: nil, is_reference: false,
            area_per_unit: nil, revenue_per_area: nil, region: nil, groups: [],
            crop_stages: [], created_at: nil, updated_at: nil
          )
          crop_stage_entity = Domain::Crop::Entities::CropStageEntity.new(
            id: 2, crop_id: 1, name: "s", order: 1,
            temperature_requirement: nil, thermal_requirement: nil,
            sunshine_requirement: nil, nutrient_requirement: nil,
            created_at: nil, updated_at: nil
          )
          user = Struct.new(:id, :admin?, keyword_init: true).new(id: 1, admin?: false)

          crop_gw = Minitest::Mock.new
          crop_gw.expect(:find_by_id, crop_entity, [1])
          stage_gw = Minitest::Mock.new
          stage_gw.expect(:find_by_id, crop_stage_entity, [2])

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [1])

          failure = Class.new do
            def on_not_found
              raise "must not call"
            end
          end.new

          interactor = CropLoadMastersAuthorizedCropStageInteractor.new(
            failure_presenter: failure,
            user_id: 1,
            crop_gateway: crop_gw,
            crop_stage_gateway: stage_gw,
            user_lookup: user_lookup
          )

          out = interactor.call(
            Domain::Crop::Dtos::CropLoadAuthorizedCropStageInput.new(crop_id: 1, crop_stage_id: 2)
          )
          assert_equal 1, out.crop_entity.id
          crop_gw.verify
          stage_gw.verify
          user_lookup.verify
        end
      end
    end
  end
end
