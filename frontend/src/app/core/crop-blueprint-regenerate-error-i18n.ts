import { HttpErrorResponse } from '@angular/common/http';

const BLUEPRINT_ERROR_PREFIX = 'crops.show.blueprint_errors.';

const KNOWN_ERROR_CODES = new Set([
  'missing_blueprints',
  'missing_agrr_requirement',
  'blueprint_generation_failed',
  'ai_unavailable',
  'ai_execution_failed',
  'generic'
]);

const READINESS_BLOCKING_ERROR_CODES = new Set([
  'missing_blueprints',
  'missing_agrr_requirement'
]);

function errorCodeFromBody(error: HttpErrorResponse): string | null {
  const body = error.error;
  if (body == null || typeof body !== 'object') {
    return null;
  }
  const code = (body as { error_code?: unknown }).error_code;
  return typeof code === 'string' && code.length > 0 ? code : null;
}

export function cropBlueprintRegenerateErrorI18nKey(error: unknown): string {
  if (error instanceof HttpErrorResponse) {
    const code = errorCodeFromBody(error);
    if (code && KNOWN_ERROR_CODES.has(code)) {
      return `${BLUEPRINT_ERROR_PREFIX}${code}`;
    }
    if (error.status === 503) {
      return `${BLUEPRINT_ERROR_PREFIX}ai_unavailable`;
    }
    if (error.status === 422) {
      return `${BLUEPRINT_ERROR_PREFIX}generic`;
    }
  }
  return `${BLUEPRINT_ERROR_PREFIX}generic`;
}

export function isBlueprintRegenerateErrorKey(message: string): boolean {
  return message.startsWith(BLUEPRINT_ERROR_PREFIX);
}

export function blueprintRegenerateErrorShowsRetry(message: string): boolean {
  if (!isBlueprintRegenerateErrorKey(message)) {
    return false;
  }
  const code = message.slice(BLUEPRINT_ERROR_PREFIX.length);
  return !READINESS_BLOCKING_ERROR_CODES.has(code);
}
