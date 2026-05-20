# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Field
    module Policies
      class FieldCreateAttributesTest < DomainLibTestCase
        test "merge_for_build sets user_id and farm_id" do
          h = FieldCreateAttributes.merge_for_build(user_id: 1, farm_id: 2, attrs: { name: "A" })
          assert_equal 1, h[:user_id]
          assert_equal 2, h[:farm_id]
          assert_equal "A", h[:name]
        end
      end
    end
  end
end
