# frozen_string_literal: true

module DeletionUndo
  class Manager
    DEFAULT_TTL = 5.minutes

    class << self
      def default_ttl
        seconds = ENV.fetch("DELETION_UNDO_TTL_SECONDS", nil)&.to_i
        seconds && seconds.positive? ? seconds.seconds : DEFAULT_TTL
      end

      def schedule(record:, actor: nil, toast_message: nil, auto_hide_after: nil, metadata: {})
        raise ArgumentError, "record must be persisted" unless record&.persisted?

        gateway = Adapters::DeletionUndo::Gateways::DeletionUndoActiveRecordGateway.new
        entity = gateway.schedule(
          resource_type: record.class.name,
          resource_id: record.id,
          actor_id: actor&.id,
          toast_message: toast_message,
          auto_hide_after: auto_hide_after,
          metadata: metadata
        )
        ::DeletionUndoEvent.find(entity.id)
      end

      def restore!(undo_token:)
        event = DeletionUndoEvent.find(undo_token)
        event.expire_if_needed!

        raise Domain::DeletionUndo::Exceptions::DeletionUndoExpiredError, "Undo token has expired" if event.expired? || !event.scheduled?

        ActiveRecord::Base.transaction do
          SnapshotRestorer.new(event.snapshot).restore!
          event.mark_restored!
        end

        event
      rescue Domain::DeletionUndo::Exceptions::DeletionUndoExpiredError
        event&.mark_failed!(error_message: "Token expired") unless event&.expired?
        raise
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved, ActiveRecord::RecordNotUnique => e
        event&.mark_failed!(error_message: e.message)
        raise Domain::DeletionUndo::Exceptions::DeletionUndoRestoreConflictError, e.message
      end

      def finalize_expired!(now: Time.current)
        DeletionUndoEvent.scheduled.where("expires_at <= ?", now).find_each(&:expire_if_needed!)
      end
    end
  end
end
