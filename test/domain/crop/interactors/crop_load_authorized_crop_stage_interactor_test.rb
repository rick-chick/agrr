# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Crop
    module Interactors
      class CropLoadAuthorizedCropStageInteractorTest < DomainLibTestCase
        test "returns bundle when gateway succeeds" do
          crop_entity = Domain::Crop::Entities::CropEntity.new(id: 1, user_id: 1, name: "x", variety: nil, is_reference: false, area_per_unit: nil, revenue_per_area: nil, region: nil, groups: [], crop_stages: [], created_at: nil, updated_at: nil)
          crop_stage_entity = Domain::Crop::Entities::CropStageEntity.new(id: 2, crop_id: 1, name: "s", order: 1, temperature_requirement: nil, thermal_requirement: nil, sunshine_requirement: nil, nutrient_requirement: nil, created_at: nil, updated_at: nil)
          dto = Domain::Crop::Dtos::AuthorizedCropStageInCropContext.new(
            crop_entity: crop_entity,
            crop_stage_entity: crop_stage_entity
          )
          user = stub(id: 1, admin?: false)

          gw = Class.new do
            attr_reader :captured_for_edit

            def initialize(bundle)
              @bundle = bundle
            end

            def find_crop_with_crop_stage_bundle!(crop_id, crop_stage_id, for_edit:)
              raise ArgumentError unless crop_id == 1 && crop_stage_id == 2

              @captured_for_edit = for_edit
              @bundle
            end
          end.new(dto)

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ 9 ])

          failure = Class.new do
            def on_not_found
              raise "must not call"
            end
          end.new

          interactor = CropLoadAuthorizedCropStageInteractor.new(
            failure_presenter: failure,
            user_id: 9,
            gateway: gw,
            user_lookup: user_lookup,
            for_edit: false
          )

          out = interactor.call(
            Domain::Crop::Dtos::CropLoadAuthorizedCropStageInput.new(crop_id: "1", crop_stage_id: "2")
          )
          assert_same dto, out
          assert_equal false, gw.captured_for_edit
          user_lookup.verify
        end

        test "passes for_edit true to gateway when constructed with for_edit true" do
          crop_entity2 = Domain::Crop::Entities::CropEntity.new(id: 3, user_id: 1, name: "y", variety: nil, is_reference: false, area_per_unit: nil, revenue_per_area: nil, region: nil, groups: [], crop_stages: [], created_at: nil, updated_at: nil)
          crop_stage_entity2 = Domain::Crop::Entities::CropStageEntity.new(id: 4, crop_id: 3, name: "t", order: 1, temperature_requirement: nil, thermal_requirement: nil, sunshine_requirement: nil, nutrient_requirement: nil, created_at: nil, updated_at: nil)
          dto = Domain::Crop::Dtos::AuthorizedCropStageInCropContext.new(
            crop_entity: crop_entity2,
            crop_stage_entity: crop_stage_entity2
          )
          user = stub(id: 1, admin?: false)

          gw = Class.new do
            attr_reader :captured_for_edit

            def initialize(bundle)
              @bundle = bundle
            end

            def find_crop_with_crop_stage_bundle!(crop_id, crop_stage_id, for_edit:)
              @captured_for_edit = for_edit
              @bundle
            end
          end.new(dto)

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ 1 ])

          failure = Class.new do
            def on_not_found
              raise "must not call"
            end
          end.new

          interactor = CropLoadAuthorizedCropStageInteractor.new(
            failure_presenter: failure,
            user_id: 1,
            gateway: gw,
            user_lookup: user_lookup,
            for_edit: true
          )

          assert_same dto, interactor.call(
            Domain::Crop::Dtos::CropLoadAuthorizedCropStageInput.new(crop_id: 3, crop_stage_id: 4)
          )
          assert_equal true, gw.captured_for_edit
          user_lookup.verify
        end

        test "delegates to failure presenter on_not_found when interactor denies edit" do
          crop_entity = Domain::Crop::Entities::CropEntity.new(id: 1, user_id: 99, name: "x", variety: nil, is_reference: false, area_per_unit: nil, revenue_per_area: nil, region: nil, groups: [], crop_stages: [], created_at: nil, updated_at: nil)
          crop_stage_entity = Domain::Crop::Entities::CropStageEntity.new(id: 2, crop_id: 1, name: "s", order: 1, temperature_requirement: nil, thermal_requirement: nil, sunshine_requirement: nil, nutrient_requirement: nil, created_at: nil, updated_at: nil)
          dto = Domain::Crop::Dtos::AuthorizedCropStageInCropContext.new(
            crop_entity: crop_entity,
            crop_stage_entity: crop_stage_entity
          )
          user = stub(id: 1, admin?: false)

          gateway = Minitest::Mock.new
          gateway.expect(:find_crop_with_crop_stage_bundle!, dto) do |crop_id, crop_stage_id, for_edit:|
            crop_id == 1 && crop_stage_id == 2 && for_edit == true
          end

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ 9 ])

          failure = Minitest::Mock.new
          failure.expect(:on_not_found, nil)

          interactor = CropLoadAuthorizedCropStageInteractor.new(
            failure_presenter: failure,
            user_id: 9,
            gateway: gateway,
            user_lookup: user_lookup,
            for_edit: true
          )

          assert_nil interactor.call(
            Domain::Crop::Dtos::CropLoadAuthorizedCropStageInput.new(crop_id: 1, crop_stage_id: 2)
          )
          gateway.verify
          user_lookup.verify
          failure.verify
        end

        test "delegates to failure presenter on_not_found when gateway raises record not found" do
          gateway = Minitest::Mock.new
          gateway.expect(:find_crop_with_crop_stage_bundle!, nil) do |crop_id, crop_stage_id, for_edit:|
            raise Domain::Shared::Exceptions::RecordNotFound, "gone" if crop_id == 99 && crop_stage_id == 88 && for_edit == false
          end

          user = stub(id: 1, admin?: false)
          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ 9 ])

          failure = Minitest::Mock.new
          failure.expect(:on_not_found, nil)

          interactor = CropLoadAuthorizedCropStageInteractor.new(
            failure_presenter: failure,
            user_id: 9,
            gateway: gateway,
            user_lookup: user_lookup,
            for_edit: false
          )

          assert_nil interactor.call(
            Domain::Crop::Dtos::CropLoadAuthorizedCropStageInput.new(crop_id: 99, crop_stage_id: 88)
          )
          gateway.verify
          user_lookup.verify
          failure.verify
        end
      end
    end
  end
end
