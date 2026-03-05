# frozen_string_literal: true

module Domain
  module DeletionUndo
    module Dtos
      class DeletionUndoRestoreInputDto
        attr_reader :undo_token

        def initialize(undo_token:)
          @undo_token = undo_token
        end
      end
    end
  end
end