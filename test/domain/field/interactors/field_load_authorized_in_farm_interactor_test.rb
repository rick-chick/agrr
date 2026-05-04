# frozen_string_literal: true

require "test_helper"

module Domain
  module Field
    module Interactors
      class FieldLoadAuthorizedInFarmInteractorTest < ActiveSupport::TestCase
        setup do
          @fixed_at = Time.utc(2026, 1, 15, 12, 0, 0).freeze
          @entity = Entities::FieldEntity.new(
            id: 7,
            farm_id: 3,
            user_id: 9,
            name: "North",
            description: nil,
            created_at: @fixed_at,
            updated_at: @fixed_at,
            area: nil,
            daily_fixed_cost: nil,
            region: nil
          )
        end

        test "returns bundle when gateway succeeds" do
          persisted = Object.new
          dto = Domain::Field::Dtos::AuthorizedFieldLoadedInFarmDto.new(
            field_entity: @entity,
            persisted_field: persisted
          )

          gw = Class.new do
            attr_accessor :captured_farm_id, :captured_field_id

            def initialize(bundle)
              @bundle = bundle
            end

            def find_authorized_field_loaded_in_farm!(user, farm_id, field_id)
              raise ArgumentError unless user == :user_stub && farm_id == 3 && field_id == 7

              @captured_farm_id = farm_id
              @captured_field_id = field_id
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

          interactor = FieldLoadAuthorizedInFarmInteractor.new(
            failure_presenter: failure,
            user_id: 9,
            gateway: gw,
            user_lookup: user_lookup
          )

          bundle = interactor.call("3", "7")

          assert_equal @entity, bundle.field_entity
          assert_same persisted, bundle.persisted_field
          assert_equal 3, gw.captured_farm_id
          assert_equal 7, gw.captured_field_id
          user_lookup.verify
        end

        test "delegates to failure presenter on policy denial" do
          gateway = Minitest::Mock.new
          gateway.expect(:find_authorized_field_loaded_in_farm!, nil) do |*_args|
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, :user_stub, [ 9 ])

          failure = Minitest::Mock.new
          failure.expect(:on_permission_denied, nil)

          interactor = FieldLoadAuthorizedInFarmInteractor.new(
            failure_presenter: failure,
            user_id: 9,
            gateway: gateway,
            user_lookup: user_lookup
          )

          assert_nil interactor.call(3, 7)
          gateway.verify
          user_lookup.verify
          failure.verify
        end

        test "delegates to failure presenter on record not found" do
          gateway = Minitest::Mock.new
          gateway.expect(:find_authorized_field_loaded_in_farm!, nil) do |*_args|
            raise Domain::Shared::Exceptions::RecordNotFound, "gone"
          end

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, :user_stub, [ 9 ])

          failure = Minitest::Mock.new
          failure.expect(:on_not_found, nil)

          interactor = FieldLoadAuthorizedInFarmInteractor.new(
            failure_presenter: failure,
            user_id: 9,
            gateway: gateway,
            user_lookup: user_lookup
          )

          assert_nil interactor.call(3, 99)
          gateway.verify
          user_lookup.verify
          failure.verify
        end
      end
    end
  end
end
