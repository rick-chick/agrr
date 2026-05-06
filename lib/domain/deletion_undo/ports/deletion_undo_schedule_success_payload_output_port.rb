# frozen_string_literal: true

module Domain
  module DeletionUndo
    module Ports
      class DeletionUndoScheduleSuccessPayloadOutputPort
        def on_success(dto)
          raise NotImplementedError, "Subclasses must implement on_success"
        end

        def on_failure(dto)
          raise NotImplementedError, "Subclasses must implement on_failure"
        end
      end
    end
  end
end
