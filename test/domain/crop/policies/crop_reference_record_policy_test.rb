# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Crop
    module Policies
      class CropReferenceRecordPolicyTest < DomainLibTestCase
        test "visible_for_entry_schedule requires reference and region match" do
          ref = Entities::CropEntity.new(
            id: 1, user_id: nil, name: "R", variety: nil, is_reference: true,
            area_per_unit: 1.0, revenue_per_area: 1.0, region: "jp",
            groups: [], crop_stages: [],
            created_at: Time.utc(2026, 1, 1), updated_at: Time.utc(2026, 1, 1)
          )
          assert CropReferenceRecordPolicy.visible_for_entry_schedule?(ref, region: "jp")
          refute CropReferenceRecordPolicy.visible_for_entry_schedule?(ref, region: "us")
        end

        test "visible_for_public_plan_add_crop requires reference only" do
          ref = stub(is_reference: true, reference?: nil)
          owned = stub(is_reference: false, reference?: nil)
          assert CropReferenceRecordPolicy.visible_for_public_plan_add_crop?(ref)
          refute CropReferenceRecordPolicy.visible_for_public_plan_add_crop?(owned)
        end
      end
    end
  end
end
