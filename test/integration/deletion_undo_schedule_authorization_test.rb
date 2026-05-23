# frozen_string_literal: true

require "test_helper"

class DeletionUndoScheduleAuthorizationTest < ActiveSupport::TestCase
  test "denies schedule when actor cannot edit crop" do
    owner = create(:user)
    other = create(:user)
    crop = create(:crop, user: owner, is_reference: false)

    received = nil
    output_port = Object.new
    output_port.define_singleton_method(:on_failure) { |dto| received = dto }
    output_port.define_singleton_method(:on_success) { |_| flunk "expected failure" }

    interactor = CompositionRoot.deletion_undo_schedule_interactor(output_port: output_port)
    interactor.call(
      Domain::DeletionUndo::Dtos::DeletionUndoScheduleInput.new(
        resource_type: "Crop",
        resource_id: crop.id,
        actor_id: other.id
      )
    )

    assert_instance_of Domain::DeletionUndo::Dtos::DeletionUndoScheduleFailure, received
    assert_equal :forbidden, received.reason
  end
end
