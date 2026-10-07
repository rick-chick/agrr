/** Reads `error_code` from Angular HTTP error shapes (`error.error`). */
export function apiErrorCode(error: unknown): string | undefined {
  if (!error || typeof error !== 'object') {
    return undefined;
  }
  const envelope = error as { error?: unknown };
  const body = envelope.error;
  if (!body || typeof body !== 'object') {
    return undefined;
  }
  const code = (body as { error_code?: unknown }).error_code;
  return typeof code === 'string' ? code : undefined;
}
