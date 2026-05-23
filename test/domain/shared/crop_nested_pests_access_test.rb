# frozen_string_literal: true

require "domain_lib_test_helper"

class DomainSharedCropNestedPestsAccessTest < DomainLibTestCase
  test "assert_allowed! passes for reference crop" do
    user = domain_user_stub(id: 1, admin: true)
    crop = domain_record_entity_stub(user_id: 99, is_reference: true)

    Domain::Shared::Policies::CropNestedPestsAccess.assert_allowed!(user, crop)
  end

  test "assert_allowed! passes for crop owner" do
    user = domain_user_stub(id: 1, admin: false)
    crop = domain_record_entity_stub(user_id: 1, is_reference: false)

    Domain::Shared::Policies::CropNestedPestsAccess.assert_allowed!(user, crop)
  end

  test "assert_allowed! denies admin on another users non-reference crop" do
    user = domain_user_stub(id: 1, admin: true)
    crop = domain_record_entity_stub(user_id: 99, is_reference: false)

    assert_raises(Domain::Shared::Policies::PolicyPermissionDenied) do
      Domain::Shared::Policies::CropNestedPestsAccess.assert_allowed!(user, crop)
    end
  end
end
