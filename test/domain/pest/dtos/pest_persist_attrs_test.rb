# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Pest
    module Dtos
      class PestPersistAttrsTest < DomainLibTestCase
        test "from_normalized_hash keeps only known keys and exposes readers" do
          dto = PestPersistAttrs.from_normalized_hash(
            name: "アブラムシ",
            user_id: 9,
            is_reference: false,
            ignored_extra: "x"
          )

          assert_equal "アブラムシ", dto.name
          assert_equal 9, dto.user_id
          assert_equal false, dto.is_reference
          refute dto.to_ar_attributes.key?(:ignored_extra)
        end

        test "to_ar_attributes returns mutable dup" do
          dto = PestPersistAttrs.from_normalized_hash(name: "x", user_id: 1, is_reference: false)
          h = dto.to_ar_attributes
          h[:name] = "y"
          assert_equal "x", dto.name
        end
      end
    end
  end
end
