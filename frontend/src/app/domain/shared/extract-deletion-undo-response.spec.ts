import { describe, expect, it } from 'vitest';
import { extractDeletionUndoResponse } from './extract-deletion-undo-response';

const sample = {
  undo_token: 'token-1',
  undo_path: '/undo_deletion?undo_token=token-1',
  toast_message: 'deleted'
};

describe('extractDeletionUndoResponse', () => {
  it('returns flat undo payload', () => {
    expect(extractDeletionUndoResponse(sample)).toEqual(sample);
  });

  it('returns nested undo payload (farm/crop destroy)', () => {
    expect(extractDeletionUndoResponse({ undo: sample })).toEqual(sample);
  });

  it('returns undefined when undo_token is missing', () => {
    expect(extractDeletionUndoResponse({ undo: { toast_message: 'x' } })).toBeUndefined();
    expect(extractDeletionUndoResponse(null)).toBeUndefined();
  });
});
