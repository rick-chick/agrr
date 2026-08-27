import { ErrorDto } from '../../domain/shared/error.dto';
import { errorDtoI18nKey } from '../error-dto-i18n-key';

/** Maps load-list scope errors to an i18n key for inline page-alert-error panels. */
export function masterListLoadErrorFromDto(dto: ErrorDto, loadScope: string): string | null {
  return dto.scope === loadScope ? errorDtoI18nKey(dto) : null;
}
