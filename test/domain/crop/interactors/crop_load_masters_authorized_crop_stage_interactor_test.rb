# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Crop
    module Interactors
      class CropLoadMastersAuthorizedCropStageInteractorTest < DomainLibTestCase
        test "returns dto when gateway succeeds" do
          crop_entity = Domain::Crop::Entities::CropEntity.new(id: 1, user_id: 1, name: "x", variety: nil, is_reference: false, area_per_unit: nil, revenue_per_area: nil, region: nil, groups: [], crop_stages: [], created_at: nil, updated_at: nil)
          crop_stage_entity = Domain::Crop::Entities::CropStageEntity.new(id: 2, crop_id: 1, name: "s", order: 1, temperature_requirement: nil, thermal_requirement: nil, sunshine_requirement: nil, nutrient_requirement: nil, created_at: nil, updated_at: nil)
          dto = Domain::Crop::Dtos::AuthorizedCropStageInCropContext.new(
            crop_entity: crop_entity,
            crop_stage_entity: crop_stage_entity
          )

          gateway = mock
          gateway.expects(:find_masters_crop_with_crop_stage_bundle!).with(
            :u,
            1,
            2,
            access_filter: instance_of(Domain::Shared::ReferenceRecordAccessFilter)
          ).returns(dto)

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, :u, [ 9 ])

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
          gateway.expects(:find_masters_crop_with_crop_stage_bundle!).with(
            :u,
            1,
            99,
            access_filter: instance_of(Domain::Shared::ReferenceRecordAccessFilter)
          ).raises(Domain::Shared::Exceptions::RecordNotFound, "x")

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, :u, [ 9 ])

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
