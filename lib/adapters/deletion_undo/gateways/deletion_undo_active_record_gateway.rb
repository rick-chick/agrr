# frozen_string_literal: true

module Adapters
  module DeletionUndo
    module Gateways
      class DeletionUndoActiveRecordGateway < Domain::DeletionUndo::Gateways::DeletionUndoGateway
        def find_by_token(undo_token)
          model = ::DeletionUndoEvent.find_by(id: undo_token)
          raise Domain::DeletionUndo::Exceptions::DeletionUndoNotFoundError unless model

          build_entity(model)
        end

        def expire_if_needed(event_id)
          model = ::DeletionUndoEvent.find_by(id: event_id)
          raise Domain::DeletionUndo::Exceptions::DeletionUndoNotFoundError unless model

          model.expire_if_needed!
          build_entity(model)
        end

        def perform_restore(event_id)
          ActiveRecord::Base.transaction do
            model = ::DeletionUndoEvent.lock.find_by(id: event_id)
            raise Domain::DeletionUndo::Exceptions::DeletionUndoNotFoundError unless model

            ::DeletionUndo::SnapshotRestorer.new(model.snapshot).restore!
            model.mark_restored!
          end
        rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved, ActiveRecord::RecordNotUnique => e
          raise Domain::DeletionUndo::Exceptions::DeletionUndoRestoreConflictError, e.message
        end

        def mark_failed(event_id, error_message)
          model = ::DeletionUndoEvent.find_by(id: event_id)
          return unless model # 見つからない場合は何もしない

          model.mark_failed!(error_message: error_message)
          build_entity(model)
        end

        def schedule(record:, actor: nil, toast_message: nil, auto_hide_after: nil, metadata: {})
          ActiveRecord::Base.transaction do
            snapshot = ::DeletionUndo::SnapshotBuilder.new(record).build

            event = ::DeletionUndoEvent.create!(
              resource_type: record.class.name,
              resource_id: record.id.to_s,
              snapshot: snapshot,
              metadata: build_metadata(record, toast_message, auto_hide_after, metadata),
              deleted_by: actor,
              expires_at: Time.current + default_ttl
            )

            record.destroy!

            build_entity(event)
          end
        end

        private

        def build_entity(model)
          Domain::DeletionUndo::Entities::DeletionUndoEntity.new(
            id: model.id,
            expires_at: model.expires_at,
            status: model.state,
            metadata: model.metadata || {}
          )
        end

        def default_ttl
          seconds = ENV.fetch('DELETION_UNDO_TTL_SECONDS', nil)&.to_i
          seconds && seconds.positive? ? seconds.seconds : 5.minutes
        end

        def build_metadata(record, toast_message, auto_hide_after, metadata)
          metadata = metadata.to_h.with_indifferent_access
          metadata[:toast_message] ||= toast_message || default_toast_message(record)
          metadata[:resource_label] ||= default_resource_label(record)
          metadata[:auto_hide_after] ||= auto_hide_after if auto_hide_after
          metadata[:undo_deadline] = (Time.current + default_ttl).iso8601
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
end