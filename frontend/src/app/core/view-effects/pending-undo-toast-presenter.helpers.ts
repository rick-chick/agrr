import { DeletionUndoResponse } from '../../domain/shared/deletion-undo-response';
import { PendingUndoToastRequest } from './pending-undo-toast-view.effects';

export function pendingUndoToastFromDeletion(
  undo: DeletionUndoResponse,
  onRestored?: () => void
): PendingUndoToastRequest {
  return {
    message: undo.toast_message,
    undoPath: undo.undo_path,
    undoToken: undo.undo_token,
    onRestored,
    resourceLabel: undo.resource
  };
}
