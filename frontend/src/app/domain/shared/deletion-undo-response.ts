/**
 * 削除APIがUndo対応の場合に返すレスポンス（Rails render_deletion_undo_response の JSON）
 */
export interface DeletionUndoResponse {
  undo_token: string;
  undo_deadline?: string;
  toast_message: string;
  undo_path: string;
  auto_hide_after?: number;
  resource?: string;
  redirect_path?: string;
  resource_dom_id?: string;
}
