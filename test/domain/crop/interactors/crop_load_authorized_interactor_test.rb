# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Crop
    module Interactors
      class CropLoadAuthorizedInteractorTest < DomainLibTestCase
        TestUser = Struct.new(:id, :admin?, keyword_init: true)

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

        test "returns authorized crop when gateway succeeds" do
          user = TestUser.new(id: 1, admin?: false)

          gateway = Minitest::Mock.new
          gateway.expect(:find_by_id, @entity, [42])

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ 9 ])

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
            gateway: gateway,
            user_lookup: user_lookup
          )

          result = interactor.call(
            Domain::Crop::Dtos::CropLoadAuthorizedInput.new(crop_id: "42", for_edit: false)
          )

          assert_equal @entity, result.crop_entity
          gateway.verify
          user_lookup.verify
        end

        test "delegates to failure presenter on policy denial" do
          denied_entity = Entities::CropEntity.new(
            id: 42,
            user_id: 99,
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
          user = TestUser.new(id: 1, admin?: false)

          gateway = Minitest::Mock.new
          gateway.expect(:find_by_id, denied_entity, [42])

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ 9 ])

          failure = Minitest::Mock.new
          failure.expect(:on_permission_denied, nil)

          interactor = CropLoadAuthorizedInteractor.new(
            failure_presenter: failure,
            user_id: 9,
            gateway: gateway,
            user_lookup: user_lookup
          )

          assert_nil interactor.call(
            Domain::Crop::Dtos::CropLoadAuthorizedInput.new(crop_id: 42, for_edit: true)
          )
          gateway.verify
          user_lookup.verify
          failure.verify
        end

        test "delegates to failure presenter on record not found" do
          gateway = Minitest::Mock.new
          gateway.expect(:find_by_id, nil) do |_id|
            raise Domain::Shared::Exceptions::RecordNotFound, "gone"
          end

          user = TestUser.new(id: 1, admin?: false)
          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [9])

          failure = Minitest::Mock.new
          failure.expect(:on_not_found, nil)

          interactor = CropLoadAuthorizedInteractor.new(
            failure_presenter: failure,
            user_id: 9,
            gateway: gateway,
            user_lookup: user_lookup
          )

          assert_nil interactor.call(
            Domain::Crop::Dtos::CropLoadAuthorizedInput.new(crop_id: 99, for_edit: false)
          )
          gateway.verify
          user_lookup.verify
          failure.verify
        end
      end
    end
  end
end
