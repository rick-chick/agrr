require "action_view/record_identifier"
# frozen_string_literal: true

module DeletionUndo
  class Error < StandardError; end
  class ExpiredTokenError < Error; end
  class RestoreConflictError < Error; end

  class Manager
    DEFAULT_TTL = 5.minutes

    class << self
      def default_ttl
        seconds = ENV.fetch('DELETION_UNDO_TTL_SECONDS', nil)&.to_i
        seconds && seconds.positive? ? seconds.seconds : DEFAULT_TTL
      end

      def schedule(record:, actor: nil, toast_message: nil, auto_hide_after: nil, metadata: {})
        raise ArgumentError, 'record must be persisted' unless record&.persisted?

        ActiveRecord::Base.transaction do
          snapshot = SnapshotBuilder.new(record).build

          event = DeletionUndoEvent.create!(
            resource_type: record.class.name,
            resource_id: record.id.to_s,
            snapshot: snapshot,
            metadata: build_metadata(record, toast_message, auto_hide_after, metadata),
            deleted_by: actor,
            expires_at: Time.current + (metadata[:ttl] || default_ttl)
          )

          record.destroy!

          event
        end
      end

        def restore!(undo_token:)
          event = DeletionUndoEvent.find(undo_token)
          event.expire_if_needed!

          raise ExpiredTokenError, 'Undo token has expired' if event.expired? || !event.scheduled?

          ActiveRecord::Base.transaction do
            SnapshotRestorer.new(event.snapshot).restore!
            event.mark_restored!
          end

          event
        rescue ExpiredTokenError
          event&.mark_failed!(error_message: 'Token expired') unless event&.expired?
          raise
        rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved, ActiveRecord::RecordNotUnique => e
          event&.mark_failed!(error_message: e.message)
          raise RestoreConflictError, e.message
        end

      def finalize_expired!(now: Time.current)
        DeletionUndoEvent.scheduled.where('expires_at <= ?', now).find_each(&:expire_if_needed!)
      end

      private

      def build_metadata(record, toast_message, auto_hide_after, metadata)
        metadata = metadata.to_h.with_indifferent_access
        metadata[:toast_message] ||= toast_message || default_toast_message(record)
        metadata[:resource_label] ||= default_resource_label(record)
        metadata[:auto_hide_after] ||= auto_hide_after if auto_hide_after
        metadata[:undo_deadline] = (Time.current + (metadata[:ttl] || default_ttl)).iso8601
        metadata[:resource_dom_id] ||= ActionView::RecordIdentifier.dom_id(record)
        metadata
      end

      def default_toast_message(record)
        I18n.t(
          'deletion_undo.toast_message',
          resource: default_resource_label(record)
        )
      end

      def default_resource_label(record)
        if record.respond_to?(:display_name)
          record.display_name
        elsif record.respond_to?(:name)
          record.name
        else
          "#{record.class.model_name.human} ##{record.id}"
        end
      end
    end
  end
end

