# frozen_string_literal: true

require "test_helper"

module Domain
  module Crop
    module Interactors
      class CropLoadMastersAuthorizedCropStageInteractorTest < ActiveSupport::TestCase
        test "returns dto when gateway succeeds" do
          crop = Object.new
          stage = Object.new
          dto = Domain::Crop::Dtos::AuthorizedCropStageInCropContextDto.new(
            persisted_crop: crop,
            persisted_crop_stage: stage
          )

          gateway = Minitest::Mock.new
          gateway.expect(:find_masters_crop_stage_in_crop_for_user!, dto, [ :u, 1, 2 ])

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
          gateway.verify
          user_lookup.verify
        end

        test "calls failure presenter on record not found" do
          gateway = Minitest::Mock.new
          gateway.expect(:find_masters_crop_stage_in_crop_for_user!, nil) do
            raise Domain::Shared::Exceptions::RecordNotFound, "x"
          end

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
          gateway.verify
          user_lookup.verify
          failure.verify
        end
      end
    end
  end
end
