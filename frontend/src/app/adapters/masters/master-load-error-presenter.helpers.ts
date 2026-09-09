import { ErrorDto } from '../../domain/shared/error.dto';
import { isBackendWarmupI18nKey } from '../../core/backend-warmup/backend-warmup';
import { errorDtoI18nKey } from '../../core/error-dto-i18n-key';

export function masterLoadErrorFromDto(dto: ErrorDto): { errorKey: string; isWarmupError: boolean } {
  const errorKey = errorDtoI18nKey(dto);
  return {
    errorKey,
    isWarmupError: isBackendWarmupI18nKey(errorKey)
  };
}
