# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Shared
    module Policies
      class CropPolicyPestAssociationTest < DomainLibTestCase
        UserStub = Struct.new(:id, :anonymous?, keyword_init: true)

        test "crop_associable_with_pest? matches reference and ownership rules" do
          user = UserStub.new(id: 1, anonymous?: false)

          assert CropPolicy.crop_associable_with_pest?(
            user: user,
            crop_is_reference: true,
            crop_user_id: nil,
            crop_region: nil,
            pest_is_reference: true,
            pest_user_id: nil,
            pest_region: nil
          )

          assert_not CropPolicy.crop_associable_with_pest?(
            user: user,
            crop_is_reference: false,
            crop_user_id: 1,
            crop_region: nil,
            pest_is_reference: true,
            pest_user_id: nil,
            pest_region: nil
          )

          assert CropPolicy.crop_associable_with_pest?(
            user: user,
            crop_is_reference: true,
            crop_user_id: nil,
            crop_region: nil,
            pest_is_reference: false,
            pest_user_id: 1,
            pest_region: nil
          )

          assert CropPolicy.crop_associable_with_pest?(
            user: user,
            crop_is_reference: false,
            crop_user_id: 2,
            crop_region: nil,
            pest_is_reference: false,
            pest_user_id: 2,
            pest_region: nil
          )
        end

        test "region mismatch denies" do
          user = UserStub.new(id: 1, anonymous?: false)

          assert_not CropPolicy.crop_associable_with_pest?(
            user: user,
            crop_is_reference: true,
            crop_user_id: nil,
            crop_region: "us",
            pest_is_reference: true,
            pest_user_id: nil,
            pest_region: "jp"
          )
        end

        test "ai_affected_crop_linkable? allows reference crop for anonymous user path" do
          user = UserStub.new(id: 1, anonymous?: false)

          assert CropPolicy.ai_affected_crop_linkable?(
            user: user,
            crop_is_reference: true,
            crop_user_id: nil,
            crop_region: nil,
            pest_is_reference: false,
            pest_user_id: 1,
            pest_region: nil
          )
        end
      end
    end
  end
end
