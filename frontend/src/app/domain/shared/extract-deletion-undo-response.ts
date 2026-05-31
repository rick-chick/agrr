import { DeletionUndoResponse } from './deletion-undo-response';

function isDeletionUndoResponse(value: unknown): value is DeletionUndoResponse {
  if (!value || typeof value !== 'object') return false;
  const token = (value as DeletionUndoResponse).undo_token;
  return typeof token === 'string' && token.length > 0;
}

/**
 * Masters DELETE の JSON から Undo 情報を取り出す。
 * Rust API は flat（undo_token がトップレベル）または nested（undo キー）の両方があり得る。
 */
export function extractDeletionUndoResponse(body: unknown): DeletionUndoResponse | undefined {
  if (!body || typeof body !== 'object') return undefined;
  if (isDeletionUndoResponse(body)) return body;
  const nested = (body as { undo?: unknown }).undo;
  if (isDeletionUndoResponse(nested)) return nested;
  return undefined;
}
