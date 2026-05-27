# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Field
    module Policies
      class FieldAccessTest < DomainLibTestCase
        def farm_entity(user_id:)
          Domain::Farm::Entities::FarmEntity.new(
            id: 1,
            name: "F",
            latitude: 35.0,
            longitude: 135.0,
            region: "jp",
            user_id: user_id,
            created_at: Time.utc(2024, 1, 1),
            updated_at: Time.utc(2024, 1, 1),
            is_reference: false
          )
        end

        test "assert_owned! passes for farm owner" do
          user = domain_user_stub(id: 10, admin: false)

          FieldAccess.assert_owned!(user, farm: farm_entity(user_id: 10))
        end

        test "assert_owned! allows admin" do
          user = domain_user_stub(id: 99, admin: true)

          FieldAccess.assert_owned!(user, farm: farm_entity(user_id: 1))
        end

        test "assert_owned! raises PolicyPermissionDenied for non-owner non-admin" do
          user = domain_user_stub(id: 1, admin: false)

          assert_raises(Domain::Shared::Policies::PolicyPermissionDenied) do
            FieldAccess.assert_owned!(user, farm: farm_entity(user_id: 2))
          end
        end

        test "assert_farm_fields_list_allowed! passes for farm owner" do
          user = domain_user_stub(id: 10, admin: false)
          farm = domain_record_entity_stub(user_id: 10, is_reference: false)

          FieldAccess.assert_farm_fields_list_allowed!(user, farm)
        end

        test "assert_farm_fields_list_allowed! raises for other users farm" do
          user = domain_user_stub(id: 1, admin: false)
          farm = domain_record_entity_stub(user_id: 2, is_reference: false)

          assert_raises(Domain::Shared::Policies::PolicyPermissionDenied) do
            FieldAccess.assert_farm_fields_list_allowed!(user, farm)
          end
        end
      end
    end
  end
end
