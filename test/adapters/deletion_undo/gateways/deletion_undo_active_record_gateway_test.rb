# frozen_string_literal: true

require "test_helper"

class Adapters::DeletionUndo::Gateways::DeletionUndoActiveRecordGatewayTest < ActiveSupport::TestCase
  def setup
    @gateway = Adapters::DeletionUndo::Gateways::DeletionUndoActiveRecordGateway.new
  end

  test "schedule validates record when requested and maps RecordInvalid" do
    record = create(:crop)
    record.name = nil

    error = assert_raises(Domain::Shared::Exceptions::RecordInvalid) do
      @gateway.schedule(record: record, validate_before_schedule: true)
    end

    assert_predicate error.message, :present?
    assert_same record, error.record
    assert_not_nil error.errors
  end

  test "schedule skips validation when validate_before_schedule is false" do
    record = create(:crop)
    record.define_singleton_method(:validate!) { raise "validate! must not be called" }

    event = nil
    assert_difference("::DeletionUndoEvent.count", 1) do
      assert_difference("::Crop.count", -1) do
        event = @gateway.schedule(record: record, validate_before_schedule: false)
      end
    end

    assert_instance_of Domain::DeletionUndo::Entities::DeletionUndoEntity, event
  end

  test "schedule maps RecordNotDestroyed to domain RecordInvalid" do
    record = create(:crop)
    record.define_singleton_method(:destroy!) do
      raise ActiveRecord::RecordNotDestroyed.new("destroy failed", self)
    end

    assert_no_difference("::DeletionUndoEvent.count") do
      error = assert_raises(Domain::Shared::Exceptions::RecordInvalid) do
        @gateway.schedule(record: record)
      end
      assert_match("destroy failed", error.message)
      assert_same record, error.record
    end
  end

  test "schedule maps RecordNotSaved to domain RecordInvalid" do
    record = create(:crop)
    record.define_singleton_method(:destroy!) do
      raise ActiveRecord::RecordNotSaved.new("save failed", self)
    end

    assert_no_difference("::DeletionUndoEvent.count") do
      error = assert_raises(Domain::Shared::Exceptions::RecordInvalid) do
        @gateway.schedule(record: record)
      end
      assert_match("save failed", error.message)
      assert_same record, error.record
    end
  end

  test "schedule maps InvalidForeignKey to AssociationInUse" do
    record = create(:crop)
    record.define_singleton_method(:destroy!) do
      raise ActiveRecord::InvalidForeignKey, "foreign key violation"
    end

    assert_no_difference("::DeletionUndoEvent.count") do
      error = assert_raises(Domain::Shared::Exceptions::AssociationInUse) do
        @gateway.schedule(record: record)
      end
      assert_match("foreign key violation", error.message)
    end
  end

  test "schedule maps DeleteRestrictionError to AssociationInUse" do
    pest = create(:pest, :reference)
    create(:pesticide, :reference, pest: pest, crop: create(:crop, :reference))

    assert_no_difference("::DeletionUndoEvent.count") do
      error = assert_raises(Domain::Shared::Exceptions::AssociationInUse) do
        @gateway.schedule(record: pest)
      end
      assert_predicate error.message, :present?
    end
  end
end
