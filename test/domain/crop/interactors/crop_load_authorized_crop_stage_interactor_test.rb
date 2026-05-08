# frozen_string_literal: true

require "test_helper"

module Domain
  module Crop
    module Interactors
      class CropLoadAuthorizedCropStageInteractorTest < ActiveSupport::TestCase
        test "returns bundle when gateway succeeds" do
          crop = Object.new
          stage = Object.new
          dto = Domain::Crop::Dtos::AuthorizedCropStageInCropContextDto.new(
            persisted_crop: crop,
            persisted_crop_stage: stage
          )

          gw = Class.new do
            attr_reader :captured_for_edit

            def initialize(bundle)
              @bundle = bundle
            end

            def find_authorized_crop_with_crop_stage_bundle!(user, crop_id, crop_stage_id, for_edit:)
              raise ArgumentError unless user == :user_stub && crop_id == 1 && crop_stage_id == 2

              @captured_for_edit = for_edit
              @bundle
            end
          end.new(dto)

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, :user_stub, [ 9 ])

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

          out = interactor.call("1", "2")
          assert_same dto, out
          assert_equal false, gw.captured_for_edit
          user_lookup.verify
        end

        test "passes for_edit true to gateway when constructed with for_edit true" do
          dto = Domain::Crop::Dtos::AuthorizedCropStageInCropContextDto.new(
            persisted_crop: Object.new,
            persisted_crop_stage: Object.new
          )

          gw = Class.new do
            attr_reader :captured_for_edit

            def initialize(bundle)
              @bundle = bundle
            end

            def find_authorized_crop_with_crop_stage_bundle!(user, crop_id, crop_stage_id, for_edit:)
              @captured_for_edit = for_edit
              @bundle
            end
          end.new(dto)

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, :u, [ 1 ])

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

          assert_same dto, interactor.call(3, 4)
          assert_equal true, gw.captured_for_edit
          user_lookup.verify
        end

        test "delegates to failure presenter on_not_found when gateway raises policy denial" do
          gateway = Minitest::Mock.new
          gateway.expect(:find_authorized_crop_with_crop_stage_bundle!, nil) do
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, :user_stub, [ 9 ])

          failure = Minitest::Mock.new
          failure.expect(:on_not_found, nil)

          interactor = CropLoadAuthorizedCropStageInteractor.new(
            failure_presenter: failure,
            user_id: 9,
            gateway: gateway,
            user_lookup: user_lookup,
            for_edit: true
          )

          assert_nil interactor.call(1, 2)
          gateway.verify
          user_lookup.verify
          failure.verify
        end

        test "delegates to failure presenter on_not_found when gateway raises record not found" do
          gateway = Minitest::Mock.new
          gateway.expect(:find_authorized_crop_with_crop_stage_bundle!, nil) do
            raise Domain::Shared::Exceptions::RecordNotFound, "gone"
          end

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, :user_stub, [ 9 ])

          failure = Minitest::Mock.new
          failure.expect(:on_not_found, nil)

          interactor = CropLoadAuthorizedCropStageInteractor.new(
            failure_presenter: failure,
            user_id: 9,
            gateway: gateway,
            user_lookup: user_lookup,
            for_edit: false
          )

          assert_nil interactor.call(99, 88)
          gateway.verify
          user_lookup.verify
          failure.verify
        end
      end
    end
  end
end
