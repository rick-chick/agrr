import { ErrorDto } from '../../domain/shared/error.dto';
import { PendingErrorFlashRequest } from './pending-error-flash-view.effects';

export function pendingErrorFlashFromError(dto: ErrorDto | { message: string }): PendingErrorFlashRequest {
  return { type: 'error', text: dto.message };
}
