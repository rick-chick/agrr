# frozen_string_literal: true

require "test_helper"

class Adapters::DeletionUndo::Gateways::DeletionUndoActiveRecordGatewayTest < ActiveSupport::TestCase
  def setup
    @gateway = Adapters::DeletionUndo::Gateways::DeletionUndoActiveRecordGateway.new
  end

  test "schedule validates record when requested and maps RecordInvalid" do
    record = create(:crop)
    actor_id = record.user_id
    record.define_singleton_method(:validate!) do
      raise ActiveRecord::RecordInvalid.new(self)
    end
    Crop.stub(:find_by, ->(**_kwargs) { record }) do
      error = assert_raises(Domain::Shared::Exceptions::RecordInvalid) do
        @gateway.schedule(
          resource_type: "Crop",
          resource_id: record.id,
          actor_id: actor_id,
          validate_before_schedule: true
        )
      end

      assert_predicate error.message, :present?
    end
  end

  test "schedule skips validation when validate_before_schedule is false" do
    record = create(:crop)
    actor_id = record.user_id
    record.define_singleton_method(:validate!) { raise "validate! must not be called" }
    Crop.stub(:find_by, ->(**_kwargs) { record }) do
      event = nil
      assert_difference("::DeletionUndoEvent.count", 1) do
        assert_difference("::Crop.count", -1) do
          event = @gateway.schedule(
            resource_type: "Crop",
            resource_id: record.id,
            actor_id: actor_id,
            validate_before_schedule: false
          )
        end
      end

      assert_instance_of Domain::DeletionUndo::Entities::DeletionUndoEntity, event
    end
  end

  test "schedule maps RecordNotDestroyed to domain RecordInvalid" do
    record = create(:crop)
    actor_id = record.user_id
    Crop.stub(:find_by, ->(*_args, **_kwargs) { record }) do
      record.define_singleton_method(:destroy!) do
        raise ActiveRecord::RecordNotDestroyed.new("destroy failed", self)
      end

      assert_no_difference("::DeletionUndoEvent.count") do
        error = assert_raises(Domain::Shared::Exceptions::RecordInvalid) do
          @gateway.schedule(
            resource_type: "Crop",
            resource_id: record.id,
            actor_id: actor_id
          )
        end
        assert_match("destroy failed", error.message)
        assert_instance_of Domain::Shared::ValidationErrors, error.errors
      end
    end
  end

  test "schedule maps RecordNotSaved to domain RecordInvalid" do
    record = create(:crop)
    actor_id = record.user_id
    Crop.stub(:find_by, ->(*_args, **_kwargs) { record }) do
      record.define_singleton_method(:destroy!) do
        raise ActiveRecord::RecordNotSaved.new("save failed", self)
      end

      assert_no_difference("::DeletionUndoEvent.count") do
        error = assert_raises(Domain::Shared::Exceptions::RecordInvalid) do
          @gateway.schedule(
            resource_type: "Crop",
            resource_id: record.id,
            actor_id: actor_id
          )
        end
        assert_match("save failed", error.message)
        assert_instance_of Domain::Shared::ValidationErrors, error.errors
      end
    end
  end

  test "schedule maps InvalidForeignKey to AssociationInUse" do
    record = create(:crop)
    actor_id = record.user_id
    Crop.stub(:find_by, ->(*_args, **_kwargs) { record }) do
      record.define_singleton_method(:destroy!) do
        raise ActiveRecord::InvalidForeignKey, "foreign key violation"
      end

      assert_no_difference("::DeletionUndoEvent.count") do
        error = assert_raises(Domain::Shared::Exceptions::AssociationInUse) do
          @gateway.schedule(
            resource_type: "Crop",
            resource_id: record.id,
            actor_id: actor_id
          )
        end
        assert_match("foreign key violation", error.message)
      end
    end
  end

  test "schedule maps DeleteRestrictionError to AssociationInUse" do
    admin = create(:user, :admin)
    pest = create(:pest, :reference)
    create(:pesticide, :reference, pest: pest, crop: create(:crop, :reference))

    assert_no_difference("::DeletionUndoEvent.count") do
      error = assert_raises(Domain::Shared::Exceptions::AssociationInUse) do
        @gateway.schedule(
          resource_type: "Pest",
          resource_id: pest.id,
          actor_id: admin.id
        )
      end
      assert_predicate error.message, :present?
    end
  end

  test "schedule rejects unknown resource_type" do
    user = create(:user)
    assert_raises(Domain::Shared::Exceptions::RecordInvalid) do
      @gateway.schedule(resource_type: "User", resource_id: 1, actor_id: user.id)
    end
  end

  test "schedule rejects missing record id" do
    user = create(:user)
    assert_raises(Domain::Shared::Exceptions::RecordInvalid) do
      @gateway.schedule(resource_type: "Crop", resource_id: 9_999_999_999, actor_id: user.id)
    end
  end
end
