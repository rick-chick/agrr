# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module FieldCultivation
    module Policies
      class FieldCultivationClimateCropViewPolicyTest < DomainLibTestCase
        def crop_entity(is_reference:, user_id:)
          Domain::Crop::Entities::CropEntity.new(
            id: 1,
            user_id: user_id,
            name: "c",
            variety: nil,
            is_reference: is_reference
          )
        end

        test "public plan allows reference crop only" do
          user = domain_user_stub(id: 1, admin: false)
          assert FieldCultivationClimateCropViewPolicy.view_allowed?(
            user: nil,
            crop_entity: crop_entity(is_reference: true, user_id: nil),
            plan_type_public: true
          )
          assert_not FieldCultivationClimateCropViewPolicy.view_allowed?(
            user: nil,
            crop_entity: crop_entity(is_reference: false, user_id: 1),
            plan_type_public: true
          )
        end

        test "private plan allows owner crop via CropPolicy" do
          user = domain_user_stub(id: 1, admin: false)
          assert FieldCultivationClimateCropViewPolicy.view_allowed?(
            user: user,
            crop_entity: crop_entity(is_reference: false, user_id: 1),
            plan_type_public: false
          )
          assert_not FieldCultivationClimateCropViewPolicy.view_allowed?(
            user: user,
            crop_entity: crop_entity(is_reference: false, user_id: 2),
            plan_type_public: false
          )
        end
      end
    end
  end
end
