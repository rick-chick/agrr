/** Matches Rails-style i18n keys returned in API toast_message / flash payloads. */
const SERVER_I18N_KEY = /^[a-z][a-z0-9_.]*$/i;

export type ServerToastMessageParts = {
  key: string;
  params: Record<string, string>;
};

/**
 * Parses `toast_message` from deletion-undo APIs.
 * Examples: `flash.farms.deleted:Farm A`, `plans.undo.toast:Plan 1`, `pests.undo.toast`.
 */
export function parseServerToastMessage(message: string): ServerToastMessageParts | null {
  const trimmed = message.trim();
  if (!trimmed) return null;

  const colonIdx = trimmed.indexOf(':');
  if (colonIdx < 0) {
    return SERVER_I18N_KEY.test(trimmed) ? { key: trimmed, params: {} } : null;
  }

  const key = trimmed.slice(0, colonIdx);
  if (!SERVER_I18N_KEY.test(key)) return null;

  return { key, params: { name: trimmed.slice(colonIdx + 1) } };
}

export type ServerToastFallbackParams = Record<string, string>;

function applyInterpolation(template: string, params: Record<string, string>): string {
  return Object.entries(params).reduce(
    (text, [paramKey, value]) =>
      text.replaceAll(`%{${paramKey}}`, value).replaceAll(`{{${paramKey}}}`, value),
    template
  );
}

function mergeInterpolationParams(
  parsed: ServerToastMessageParts,
  fallbackParams?: ServerToastFallbackParams
): Record<string, string> | undefined {
  const merged = { ...fallbackParams, ...parsed.params };
  return Object.keys(merged).length > 0 ? merged : undefined;
}

function hasNamePlaceholder(text: string): boolean {
  return text.includes('{{name}}') || text.includes('%{name}');
}

/**
 * Resolves server toast / flash strings: i18n keys (optional `key:param` for %{name}),
 * or returns the original text when it is already human-readable.
 */
export function translateServerToastMessage(
  message: string,
  instant: (key: string, interpolateParams?: Record<string, string>) => string,
  fallbackParams?: ServerToastFallbackParams
): string {
  if (!message) return message;

  const parsed = parseServerToastMessage(message);
  if (!parsed) {
    const direct = instant(message);
    if (direct !== message) {
      return fallbackParams ? applyInterpolation(direct, fallbackParams) : direct;
    }
    if (fallbackParams && hasNamePlaceholder(message)) {
      return applyInterpolation(message, fallbackParams);
    }
    return message;
  }

  const params = mergeInterpolationParams(parsed, fallbackParams);
  const translated = instant(parsed.key, params);
  if (translated === parsed.key) {
    return message;
  }
  if (!params) {
    return translated;
  }
  return hasNamePlaceholder(translated) ? applyInterpolation(translated, params) : translated;
}
