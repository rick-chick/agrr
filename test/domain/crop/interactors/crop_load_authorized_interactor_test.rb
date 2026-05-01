# frozen_string_literal: true

require "test_helper"

module Domain
  module Crop
    module Interactors
      class CropLoadAuthorizedInteractorTest < ActiveSupport::TestCase
        setup do
          @fixed_at = Time.utc(2026, 1, 15, 12, 0, 0).freeze
          @entity = Entities::CropEntity.new(
            id: 42,
            user_id: 1,
            name: "Foo",
            variety: nil,
            is_reference: false,
            area_per_unit: nil,
            revenue_per_area: nil,
            region: nil,
            groups: [],
            crop_stages: [],
            created_at: @fixed_at,
            updated_at: @fixed_at
          )
        end

        test "returns bundle when gateway succeeds" do
          persisted = Object.new # 同一オブジェクト_identity を検証
          dto = Domain::Crop::Dtos::AuthorizedCropLoadedDto.new(crop_entity: @entity, persisted_crop: persisted)

          gw = Class.new do
            attr_accessor :captured_for_edit

            def initialize(bundle)
              @bundle = bundle
            end

            def find_authorized_crop_loaded_bundle!(user, id, for_edit:)
              raise ArgumentError unless user == :user_stub && id == 42

              @captured_for_edit = for_edit
              @bundle
            end
          end.new(dto)

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, :user_stub, [ 9 ])

          failure = Class.new do
            def on_permission_denied
              raise "must not call"
            end

            def on_not_found
              raise "must not call"
            end
          end.new

          interactor = CropLoadAuthorizedInteractor.new(
            failure_presenter: failure,
            user_id: 9,
            gateway: gw,
            user_lookup: user_lookup
          )

          bundle = interactor.call("42", for_edit: false)

          assert_equal @entity, bundle.crop_entity
          assert_same persisted, bundle.persisted_crop
          assert_equal false, gw.captured_for_edit
          user_lookup.verify
        end

        test "delegates to failure presenter on policy denial" do
          gateway = Minitest::Mock.new
          gateway.expect(:find_authorized_crop_loaded_bundle!, nil) do |*_args|
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, :user_stub, [ 9 ])

          failure = Minitest::Mock.new
          failure.expect(:on_permission_denied, nil)

          interactor = CropLoadAuthorizedInteractor.new(
            failure_presenter: failure,
            user_id: 9,
            gateway: gateway,
            user_lookup: user_lookup
          )

          assert_nil interactor.call(42, for_edit: true)
          gateway.verify
          user_lookup.verify
          failure.verify
        end

        test "delegates to failure presenter on record not found" do
          gateway = Minitest::Mock.new
          gateway.expect(:find_authorized_crop_loaded_bundle!, nil) do |*_args|
            raise Domain::Shared::Exceptions::RecordNotFound, "gone"
          end

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, :user_stub, [ 9 ])

          failure = Minitest::Mock.new
          failure.expect(:on_not_found, nil)

          interactor = CropLoadAuthorizedInteractor.new(
            failure_presenter: failure,
            user_id: 9,
            gateway: gateway,
            user_lookup: user_lookup
          )

          assert_nil interactor.call(99, for_edit: false)
          gateway.verify
          user_lookup.verify
          failure.verify
        end
      end
    end
  end
end
