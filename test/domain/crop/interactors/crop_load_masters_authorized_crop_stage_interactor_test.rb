# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Crop
    module Interactors
      class CropLoadMastersAuthorizedCropStageInteractorTest < DomainLibTestCase
        test "returns dto when gateway succeeds" do
          crop_entity = Domain::Crop::Entities::CropEntity.new(id: 1, user_id: 9, name: "x", variety: nil, is_reference: false, area_per_unit: nil, revenue_per_area: nil, region: nil, groups: [], crop_stages: [], created_at: nil, updated_at: nil)
          crop_stage_entity = Domain::Crop::Entities::CropStageEntity.new(id: 2, crop_id: 1, name: "s", order: 1, temperature_requirement: nil, thermal_requirement: nil, sunshine_requirement: nil, nutrient_requirement: nil, created_at: nil, updated_at: nil)
          dto = Domain::Crop::Dtos::AuthorizedCropStageInCropContext.new(
            crop_entity: crop_entity,
            crop_stage_entity: crop_stage_entity
          )

          gateway = mock
          gateway.expects(:find_crop_with_crop_stage_bundle!).with(1, 2, for_edit: false).returns(dto)

          user = stub(id: 9, admin?: false)
          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ 9 ])

          failure = Class.new do
            def on_not_found
              raise "must not call"
            end
          end.new

          interactor = CropLoadMastersAuthorizedCropStageInteractor.new(
            failure_presenter: failure,
            user_id: 9,
            gateway: gateway,
            user_lookup: user_lookup
          )

          out = interactor.call(1, 2)
          assert_same dto, out
          user_lookup.verify
        end

        test "calls failure presenter on record not found" do
          gateway = mock
          gateway.expects(:find_crop_with_crop_stage_bundle!).with(1, 99, for_edit: false).raises(
            Domain::Shared::Exceptions::RecordNotFound, "x"
          )

          user = stub(id: 9, admin?: false)
          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ 9 ])

          failure = Minitest::Mock.new
          failure.expect(:on_not_found, nil)

          interactor = CropLoadMastersAuthorizedCropStageInteractor.new(
            failure_presenter: failure,
            user_id: 9,
            gateway: gateway,
            user_lookup: user_lookup
          )

          assert_nil interactor.call(1, 99)
          user_lookup.verify
          failure.verify
        end
      end
    end
  end
end
