# frozen_string_literal: true

module Domain
  module DeletionUndo
    module Ports
      class DeletionUndoRestoreOutputPort
        def on_success(output_dto)
          raise NotImplementedError, "Subclasses must implement on_success"
        end

        def on_failure(error_dto)
          raise NotImplementedError, "Subclasses must implement on_failure"
        end
      end
    end
  end
end