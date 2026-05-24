# frozen_string_literal: true

require "domain_lib_test_helper"

class Domain::Farm::Policies::FarmReferenceOwnershipPolicyTest < DomainLibTestCase
  Policy = Domain::Farm::Policies::FarmReferenceOwnershipPolicy

  test "reference_farm_user_valid? は非参照農場なら常に true" do
    assert Policy.reference_farm_user_valid?(is_reference: false, owner_is_anonymous: false)
  end

  test "reference_farm_user_valid? は参照農場はアノニマス所有者のみ" do
    assert Policy.reference_farm_user_valid?(is_reference: true, owner_is_anonymous: true)
    assert_not Policy.reference_farm_user_valid?(is_reference: true, owner_is_anonymous: false)
  end
end
