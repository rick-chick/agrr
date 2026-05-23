# frozen_string_literal: true

require "domain_lib_test_helper"

class DomainDeletionUndoScheduleAuthorizationTest < DomainLibTestCase
  test "schedule_allowed? permits crop owner to schedule crop deletion" do
    user = domain_user_stub(id: 1, admin: false)
    record = schedulable_record_stub("Crop", user_id: 1, is_reference: false)

    assert Domain::DeletionUndo::ScheduleAuthorization.schedule_allowed?(user, record)
  end

  test "schedule_allowed? denies other user on non-reference crop" do
    user = domain_user_stub(id: 1, admin: false)
    record = schedulable_record_stub("Crop", user_id: 99, is_reference: false)

    assert_not Domain::DeletionUndo::ScheduleAuthorization.schedule_allowed?(user, record)
  end
end
