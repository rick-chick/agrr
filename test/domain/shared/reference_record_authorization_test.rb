# frozen_string_literal: true

require "domain_lib_test_helper"

class DomainSharedReferenceRecordAuthorizationTest < DomainLibTestCase
  UserStub = Struct.new(:id, :admin, keyword_init: true) do
    def admin?
      admin
    end
  end

  RecordStub = Struct.new(:is_reference, :user_id, keyword_init: true)

  setup do
    @user = UserStub.new(id: 1, admin: false)
    @filter = Domain::Shared::Policies::CropPolicy.record_access_filter(@user)
  end

  test "assert_view_allowed! passes when policy allows" do
    record = RecordStub.new(is_reference: true, user_id: 99)
    Domain::Shared::ReferenceRecordAuthorization.assert_view_allowed!(@filter, record)
  end

  test "assert_view_allowed! raises PolicyPermissionDenied when policy denies" do
    record = RecordStub.new(is_reference: false, user_id: 99)
    assert_raises(Domain::Shared::Policies::PolicyPermissionDenied) do
      Domain::Shared::ReferenceRecordAuthorization.assert_view_allowed!(@filter, record)
    end
  end

  test "assert_edit_allowed! raises when non-owner private record" do
    record = RecordStub.new(is_reference: false, user_id: 99)
    assert_raises(Domain::Shared::Policies::PolicyPermissionDenied) do
      Domain::Shared::ReferenceRecordAuthorization.assert_edit_allowed!(@filter, record)
    end
  end
end
