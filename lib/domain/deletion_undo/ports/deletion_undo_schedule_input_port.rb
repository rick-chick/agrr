# frozen_string_literal: true

module Domain
  module DeletionUndo
    module Ports
      class DeletionUndoScheduleInputPort
        def call(input_dto)
          raise NotImplementedError, "Subclasses must implement call"
        end
      end
    end
  end
end