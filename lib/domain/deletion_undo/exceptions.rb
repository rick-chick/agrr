# frozen_string_literal: true

module Domain
  module DeletionUndo
    module Exceptions
      class DeletionUndoError < StandardError; end
      class DeletionUndoNotFoundError < DeletionUndoError; end
      class DeletionUndoExpiredError < DeletionUndoError; end
      class DeletionUndoRestoreConflictError < DeletionUndoError; end
    end
  end
end