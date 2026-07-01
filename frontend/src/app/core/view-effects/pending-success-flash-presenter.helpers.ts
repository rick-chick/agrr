import { PendingSuccessFlashRequest } from './pending-success-flash-view.effects';

export function pendingSuccessFlashFromText(text: string): PendingSuccessFlashRequest {
  return { type: 'success', text };
}
