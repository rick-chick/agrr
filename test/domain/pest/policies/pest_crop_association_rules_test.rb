# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Pest
    module Policies
      class PestCropAssociationRulesTest < DomainLibTestCase
        test "crop_accessible_for_pest? matches reference and ownership rules" do
          assert PestCropAssociationRules.crop_accessible_for_pest?(
            crop_is_reference: true,
            crop_user_id: nil,
            crop_region: nil,
            pest_is_reference: true,
            pest_user_id: nil,
            pest_region: nil,
            actor_user_id: 1
          )

          assert_not PestCropAssociationRules.crop_accessible_for_pest?(
            crop_is_reference: false,
            crop_user_id: 1,
            crop_region: nil,
            pest_is_reference: true,
            pest_user_id: nil,
            pest_region: nil,
            actor_user_id: 1
          )

          assert PestCropAssociationRules.crop_accessible_for_pest?(
            crop_is_reference: false,
            crop_user_id: 2,
            crop_region: nil,
            pest_is_reference: false,
            pest_user_id: 2,
            pest_region: nil,
            actor_user_id: 2
          )
        end

        test "region mismatch denies" do
          assert_not PestCropAssociationRules.crop_accessible_for_pest?(
            crop_is_reference: true,
            crop_user_id: nil,
            crop_region: "us",
            pest_is_reference: true,
            pest_user_id: nil,
            pest_region: "jp",
            actor_user_id: 1
          )
        end
      end
    end
  end
end
