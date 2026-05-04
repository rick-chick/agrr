# frozen_string_literal: true

module Domain
  module DeletionUndo
    module Dtos
      class DeletionUndoScheduleInputDto
        attr_reader :record, :actor, :toast_message, :auto_hide_after, :metadata, :validate_before_schedule

        def initialize(record:, actor: nil, toast_message: nil, auto_hide_after: nil, metadata: {},
                       validate_before_schedule: false)
          @record = record
          @actor = actor
          @toast_message = toast_message
          @auto_hide_after = auto_hide_after
          @metadata = metadata
          @validate_before_schedule = validate_before_schedule
        end
      end
    end
  end
end
