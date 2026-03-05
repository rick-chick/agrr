# frozen_string_literal: true

module Domain
  module DeletionUndo
    module Dtos
      class DeletionUndoRestoreOutputDto
        attr_reader :status, :undo_token

        def initialize(status:, undo_token:)
          @status = status
          @undo_token = undo_token
        end
      end
    end
  end
end