# frozen_string_literal: true

module Domain
  module DeletionUndo
    module Gateways
      class DeletionUndoGateway
        def find_by_token(undo_token)
          raise NotImplementedError, "Subclasses must implement find_by_token"
        end

        def expire_if_needed(event_id)
          raise NotImplementedError, "Subclasses must implement expire_if_needed"
        end

        def perform_restore(event_id)
          raise NotImplementedError, "Subclasses must implement perform_restore"
        end

        def mark_failed(event_id, error_message)
          raise NotImplementedError, "Subclasses must implement mark_failed"
        end

        def schedule(record:, actor: nil, toast_message: nil, auto_hide_after: nil, metadata: {})
          raise NotImplementedError, "Subclasses must implement schedule"
        end
      end
    end
  end
end