require 'test_helper'

module DeletionUndo
  class SnapshotRestorerTest < ActiveSupport::TestCase
    test 'raises error when reference snapshot record is missing' do
      missing_id = SecureRandom.uuid

      snapshot = {
        'model' => 'Pesticide',
        'attributes' => { 'id' => missing_id },
        'reference' => true
      }

      assert_raises DeletionUndo::SnapshotRestorer::ReferenceRecordNotFoundError do
        SnapshotRestorer.new(snapshot).restore!
      end
    end
  end
end


