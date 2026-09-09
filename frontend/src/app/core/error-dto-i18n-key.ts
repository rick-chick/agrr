import { ErrorDto } from '../domain/shared/error.dto';
import { backendWarmupI18nKeyFromMessage } from './backend-warmup/backend-warmup';

const TRANSLATION_KEY_PATTERN = /^[a-z][a-z0-9_]*(?:\.[a-z0-9_]+)+$/;

/** Returns true when value is an ngx-translate key, not raw user-facing text. */
export function isTranslationKey(value: string): boolean {
  return TRANSLATION_KEY_PATTERN.test(value);
}

/**
 * Maps presenter ErrorDto message to an i18n key.
 * Usecases should prefer apiErrorI18nKey at the gateway boundary; this helper
 * prevents raw HTTP strings from reaching MasterLoadErrorPanel.
 */
export function errorDtoI18nKey(dto: ErrorDto | { message: string }): string {
  const { message } = dto;
  if (isTranslationKey(message)) {
    return message;
  }

  const warmupKey = backendWarmupI18nKeyFromMessage(message);
  if (warmupKey) {
    return warmupKey;
  }

  const lowered = message.toLowerCase();
  if (lowered.includes('not found') || /\b404\b/.test(lowered)) {
    return 'common.api_error.not_found';
  }
  if (lowered.includes('unauthorized') || /\b401\b/.test(lowered)) {
    return 'common.api_error.unauthorized';
  }
  if (lowered.includes('forbidden') || /\b403\b/.test(lowered)) {
    return 'common.api_error.forbidden';
  }
  return 'common.api_error.generic';
}
