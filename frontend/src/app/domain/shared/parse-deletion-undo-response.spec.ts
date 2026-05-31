import { describe, expect, it } from 'vitest';
import { parseDeletionUndoResponse } from './parse-deletion-undo-response';

const sample = {
  undo_token: 'token-1',
  undo_path: '/undo_deletion?undo_token=token-1',
  toast_message: 'deleted'
};

describe('parseDeletionUndoResponse', () => {
  it('returns flat undo payload', () => {
    expect(parseDeletionUndoResponse(sample)).toEqual(sample);
  });

  it('returns nested undo payload', () => {
    expect(parseDeletionUndoResponse({ undo: sample })).toEqual(sample);
  });

  it('returns undefined when undo_token is missing', () => {
    expect(parseDeletionUndoResponse({ undo: { toast_message: 'x' } })).toBeUndefined();
    expect(parseDeletionUndoResponse(null)).toBeUndefined();
  });
});
