import { DeletionUndoResponse } from './deletion-undo-response';

function isDeletionUndoResponse(value: unknown): value is DeletionUndoResponse {
  if (!value || typeof value !== 'object') return false;
  const token = (value as DeletionUndoResponse).undo_token;
  return typeof token === 'string' && token.length > 0;
}

/** DELETE レスポンス（flat または `{ undo: … }`）から Undo 情報を取り出す。 */
export function parseDeletionUndoResponse(body: unknown): DeletionUndoResponse | undefined {
  if (!body || typeof body !== 'object') return undefined;
  if (isDeletionUndoResponse(body)) return body;
  const nested = (body as { undo?: unknown }).undo;
  if (isDeletionUndoResponse(nested)) return nested;
  return undefined;
}
