# frozen_string_literal: true

module Domain
  module DeletionUndo
    module Entities
      class DeletionUndoEntity
        attr_reader :id, :expires_at, :status, :metadata

        def initialize(id:, expires_at:, status:, metadata: {})
          @id = id
          @expires_at = expires_at
          @status = status
          @metadata = metadata || {}
        end

        def expired?
          Time.current > expires_at
        end

        def scheduled?
          status == 'scheduled'
        end

        def restored?
          status == 'restored'
        end

        def failed?
          status == 'failed'
        end

        def undo_token
          id
        end

        # API Presenter 互換（DeletionUndoEvent と同様に metadata から取得）
        def toast_message
          metadata['toast_message']
        end

        def auto_hide_after
          metadata['auto_hide_after'] || 5
        end
      end
    end
  end
end