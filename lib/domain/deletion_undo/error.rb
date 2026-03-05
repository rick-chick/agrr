# frozen_string_literal: true

module Domain
  module DeletionUndo
    # For constant lookup from Domain::* context (e.g. Domain::CultivationPlan::Interactors).
    # When code does `rescue DeletionUndo::Error` or `DeletionUndo::Error.new`,
    # Ruby resolves DeletionUndo to Domain::DeletionUndo.
    Error = Exceptions::DeletionUndoError
  end
end
