function isRecord(value: unknown): value is Record<string, unknown> {
  return value != null && typeof value === 'object' && !Array.isArray(value);
}

/** Parses `errors` as a non-empty string array from an API JSON body (not HttpErrorResponse). */
export function apiErrorMessagesFromBody(body: unknown): string[] {
  if (!isRecord(body)) {
    return [];
  }
  const errors = body['errors'];
  if (!Array.isArray(errors)) {
    return [];
  }
  const result: string[] = [];
  for (const item of errors) {
    if (typeof item !== 'string') {
      continue;
    }
    const trimmed = item.trim();
    if (trimmed.length > 0) {
      result.push(trimmed);
    }
  }
  return result;
}

export function apiErrorBodyHasMessage(body: unknown, key: string): boolean {
  return apiErrorMessagesFromBody(body).includes(key);
}

export function firstApiErrorMessageFromBody(body: unknown): string | null {
  const messages = apiErrorMessagesFromBody(body);
  return messages.length > 0 ? messages[0] : null;
}
