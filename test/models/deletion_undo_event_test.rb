require 'test_helper'

class DeletionUndoEventTest < ActiveSupport::TestCase
  test 'assigns_uuid_when_id_is_blank_string' do
    event = DeletionUndoEvent.create!(
      id: '',
      resource_type: 'Farm',
      resource_id: SecureRandom.uuid,
      snapshot: { 'model' => 'Farm', 'attributes' => { 'id' => SecureRandom.uuid } },
      metadata: {},
      expires_at: 10.minutes.from_now
    )

    assert_match(/\A[0-9a-fA-F-]{36}\z/, event.id)
  end
end
