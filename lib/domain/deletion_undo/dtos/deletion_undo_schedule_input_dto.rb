# frozen_string_literal: true

module Domain
  module DeletionUndo
    module Dtos
      class DeletionUndoScheduleInputDto
        attr_reader :record, :actor, :toast_message, :auto_hide_after, :metadata

        def initialize(record:, actor: nil, toast_message: nil, auto_hide_after: nil, metadata: {})
          @record = record
          @actor = actor
          @toast_message = toast_message
          @auto_hide_after = auto_hide_after
          @metadata = metadata
        end
      end
    end
  end
end