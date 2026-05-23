# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Field
    module Interactors
      class FieldLoadAuthorizedInFarmInteractorTest < DomainLibTestCase
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
          snapshot = Domain::Farm::Dtos::FieldMasterFormSnapshot.new(
            attributes: { name: "North", farm_id: 3 }, new_record: false, id: 7
          )
          dto = Domain::Field::Dtos::AuthorizedFieldLoadedInFarm.new(
            field_entity: @entity,
            master_form_snapshot: snapshot
          )
          user = stub(id: 9, admin?: false)
          farm_entity = stub(user_id: 9, is_reference: false)
          list = Domain::Field::Results::FarmFieldsList.new(farm: farm_entity, fields: [])

          gw = mock
          gw.expects(:farm_fields_list).with(3).returns(list)
          gw.expects(:find_field_loaded_in_farm!).with(3, 7).returns(dto)
          Domain::Field::Policies::FieldAccess.expects(:find_owned!).with(user, 7).returns(Object.new)

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

          interactor = FieldLoadAuthorizedInFarmInteractor.new(
            failure_presenter: failure,
            user_id: 9,
            gateway: gw,
            user_lookup: user_lookup
          )

          bundle = interactor.call("3", "7")

          assert_equal @entity, bundle.field_entity
          assert_same snapshot, bundle.master_form_snapshot
          user_lookup.verify
        end

        test "delegates to failure presenter on policy denial" do
          user = stub(id: 9, admin?: false)
          farm_entity = stub(user_id: 99, is_reference: false)
          list = Domain::Field::Results::FarmFieldsList.new(farm: farm_entity, fields: [])

          gateway = mock
          gateway.expects(:farm_fields_list).with(3).returns(list)
          gateway.expects(:find_field_loaded_in_farm!).never
          Domain::Field::Policies::FieldAccess.expects(:find_owned!).never

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ 9 ])

          failure = Minitest::Mock.new
          failure.expect(:on_permission_denied, nil)

          interactor = FieldLoadAuthorizedInFarmInteractor.new(
            failure_presenter: failure,
            user_id: 9,
            gateway: gateway,
            user_lookup: user_lookup
          )

          assert_nil interactor.call(3, 7)
          user_lookup.verify
          failure.verify
        end

        test "delegates to failure presenter on record not found" do
          user = stub(id: 9, admin?: false)
          farm_entity = stub(user_id: 9, is_reference: false)
          list = Domain::Field::Results::FarmFieldsList.new(farm: farm_entity, fields: [])

          gateway = mock
          gateway.expects(:farm_fields_list).with(3).returns(list)
          gateway.expects(:find_field_loaded_in_farm!).with(3, 99).raises(
            Domain::Shared::Exceptions::RecordNotFound, "gone"
          )
          Domain::Field::Policies::FieldAccess.expects(:find_owned!).with(user, 99).returns(Object.new)

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ 9 ])

          failure = Minitest::Mock.new
          failure.expect(:on_not_found, nil)

          interactor = FieldLoadAuthorizedInFarmInteractor.new(
            failure_presenter: failure,
            user_id: 9,
            gateway: gateway,
            user_lookup: user_lookup
          )

          assert_nil interactor.call(3, 99)
          user_lookup.verify
          failure.verify
        end
      end
    end
  end
end
