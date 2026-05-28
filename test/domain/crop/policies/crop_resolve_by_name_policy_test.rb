# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Crop
    module Policies
      class CropResolveByNamePolicyTest < DomainLibTestCase
        setup do
          @user = domain_user_stub(id: 1, admin: false)
        end

        def crop_stub(id:, is_reference:, user_id:)
          Entities::CropEntity.new(
            id: id,
            user_id: user_id,
            name: "Tomato",
            variety: nil,
            is_reference: is_reference,
            area_per_unit: 1.0,
            revenue_per_area: 1.0,
            region: "jp",
            groups: [],
            crop_stages: [],
            created_at: Time.utc(2026, 1, 1),
            updated_at: Time.utc(2026, 1, 1)
          )
        end

        test "prefers reference crop over owned with same name" do
          ref = crop_stub(id: 10, is_reference: true, user_id: nil)
          owned = crop_stub(id: 20, is_reference: false, user_id: 1)

          id = CropResolveByNamePolicy.select_id_for_pest_ai_name_fallback(
            user: @user,
            candidates: [ owned, ref ]
          )

          assert_equal 10, id
        end

        test "returns owned crop id when no reference" do
          owned = crop_stub(id: 20, is_reference: false, user_id: 1)

          id = CropResolveByNamePolicy.select_id_for_pest_ai_name_fallback(
            user: @user,
            candidates: [ owned ]
          )

          assert_equal 20, id
        end

        test "returns nil when only other users crops" do
          other = crop_stub(id: 30, is_reference: false, user_id: 99)

          assert_nil CropResolveByNamePolicy.select_id_for_pest_ai_name_fallback(
            user: @user,
            candidates: [ other ]
          )
        end
      end
    end
  end
end
