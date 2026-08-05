import { HttpErrorResponse } from '@angular/common/http';

import { ErrorDto } from '../domain/shared/error.dto';
import { apiErrorI18nKey } from './api-error-i18n-key';

const I18N_KEY_PATTERN = /^[a-z][\w]*(\.[\w]+)+$/;

const ERROR_CODE_TO_I18N_KEY: Readonly<Record<string, string>> = {
  not_found: 'common.api_error.not_found',
  unauthorized: 'common.api_error.unauthorized',
  forbidden: 'common.api_error.forbidden',
  network_error: 'common.api_error.network',
  service_unavailable: 'common.api_error.service_unavailable'
};

function isLikelyI18nKey(message: string): boolean {
  const trimmed = message.trim();
  if (!trimmed || trimmed.includes('Http failure')) {
    return false;
  }
  if (/^HTTP \d+/i.test(trimmed)) {
    return false;
  }
  return I18N_KEY_PATTERN.test(trimmed);
}

function httpStatusFromAngularFailureMessage(message: string): number | null {
  const match = message.match(/: (\d{3}) /);
  return match ? Number(match[1]) : null;
}

function httpStatusFromRawHttpMessage(message: string): number | null {
  const match = message.match(/^HTTP (\d{3})\b/i);
  return match ? Number(match[1]) : null;
}

/**
 * Maps API / transport failures to ngx-translate keys for master load error panels.
 * Never pass raw HTTP status text to the view.
 */
export function masterLoadErrorI18nKey(dto: ErrorDto): string {
  if (dto.errorCode) {
    const mapped = ERROR_CODE_TO_I18N_KEY[dto.errorCode];
    if (mapped) {
      return mapped;
    }
  }

  if (dto.httpStatus != null) {
    return apiErrorI18nKey(new HttpErrorResponse({ status: dto.httpStatus, statusText: 'Error' }));
  }

  const message = dto.message?.trim() ?? '';
  if (isLikelyI18nKey(message)) {
    return message;
  }

  const angularStatus = httpStatusFromAngularFailureMessage(message);
  if (angularStatus != null) {
    return apiErrorI18nKey(new HttpErrorResponse({ status: angularStatus, statusText: 'Error' }));
  }

  const rawStatus = httpStatusFromRawHttpMessage(message);
  if (rawStatus != null) {
    return apiErrorI18nKey(new HttpErrorResponse({ status: rawStatus, statusText: 'Error' }));
  }

  return 'common.api_error.generic';
}
