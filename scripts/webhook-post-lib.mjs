/** @type {ReadonlySet<number>} */
export const RETRIABLE_HTTP_STATUS = new Set([429, 500, 502, 503]);

/** @type {ReadonlySet<number>} */
export const PERMANENT_HTTP_STATUS = new Set([401, 403, 404]);

export class WebhookPostError extends Error {
  /**
   * @param {string} message
   * @param {{ statusCode?: number; attempt?: number; retriable?: boolean; responseBody?: string }} [details]
   */
  constructor(message, details = {}) {
    super(message);
    this.name = 'WebhookPostError';
    this.statusCode = details.statusCode;
    this.attempt = details.attempt;
    this.retriable = details.retriable ?? false;
    this.responseBody = details.responseBody;
  }
}

/**
 * @param {number} attempt
 * @returns {number}
 */
function defaultBackoffMs(attempt) {
  return Math.min(1000 * 2 ** (attempt - 1), 30_000);
}

/**
 * @param {unknown} error
 * @returns {boolean}
 */
function isTransientCurlError(error) {
  if (!error || typeof error !== 'object') {
    return false;
  }
  const status = /** @type {{ status?: number }} */ (error).status;
  return status === 6 || status === 7 || status === 28 || status === 35 || status === 52;
}

/**
 * @param {string} raw
 * @returns {{ statusCode: number; responseBody: string }}
 */
export function parseCurlWebhookResponse(raw) {
  const trimmed = raw.trimEnd();
  const newlineIndex = trimmed.lastIndexOf('\n');
  if (newlineIndex < 0) {
    throw new WebhookPostError(`Invalid curl webhook response: ${trimmed}`);
  }
  const statusCodeStr = trimmed.slice(newlineIndex + 1).trim();
  const statusCode = Number(statusCodeStr);
  if (!Number.isInteger(statusCode)) {
    throw new WebhookPostError(`Invalid HTTP status from curl: ${statusCodeStr}`);
  }
  return {
    statusCode,
    responseBody: trimmed.slice(0, newlineIndex),
  };
}

/**
 * @param {{
 *   url: string;
 *   bearerToken: string;
 *   body: string | Record<string, unknown>;
 *   execFileSync: typeof import('node:child_process').execFileSync;
 *   sleepSync?: (ms: number) => void;
 *   maxAttempts?: number;
 *   log?: (message: string) => void;
 *   backoffMs?: (attempt: number) => number;
 * }} options
 * @returns {{ ok: true; statusCode: number; attempt: number }}
 */
export function postWebhookJson({
  url,
  bearerToken,
  body,
  execFileSync,
  sleepSync = () => {},
  maxAttempts = 3,
  log = () => {},
  backoffMs = defaultBackoffMs,
}) {
  const payload = typeof body === 'string' ? body : JSON.stringify(body);

  /** @type {Error | undefined} */
  let lastError;

  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    log(`Webhook POST attempt ${attempt}/${maxAttempts}`);
    try {
      const raw = execFileSync(
        'curl',
        [
          '-sS',
          '-w',
          '\n%{http_code}',
          '-X',
          'POST',
          url,
          '-H',
          `Authorization: Bearer ${bearerToken}`,
          '-H',
          'Content-Type: application/json',
          '-d',
          payload,
        ],
        { encoding: 'utf8' },
      );
      const { statusCode, responseBody } = parseCurlWebhookResponse(raw);

      if (statusCode >= 200 && statusCode < 300) {
        return { ok: true, statusCode, attempt };
      }

      if (PERMANENT_HTTP_STATUS.has(statusCode)) {
        throw new WebhookPostError(`Webhook POST permanent failure: HTTP ${statusCode}`, {
          statusCode,
          attempt,
          retriable: false,
          responseBody,
        });
      }

      if (RETRIABLE_HTTP_STATUS.has(statusCode) && attempt < maxAttempts) {
        log(
          `Webhook POST HTTP ${statusCode}; retrying after backoff${
            responseBody ? ` (${responseBody.slice(0, 200)})` : ''
          }`,
        );
        sleepSync(backoffMs(attempt));
        continue;
      }

      throw new WebhookPostError(`Webhook POST failed: HTTP ${statusCode}`, {
        statusCode,
        attempt,
        retriable: RETRIABLE_HTTP_STATUS.has(statusCode),
        responseBody,
      });
    } catch (error) {
      if (error instanceof WebhookPostError) {
        lastError = error;
        if (error.responseBody) {
          log(`Webhook response body: ${error.responseBody}`);
        }
        if (!error.retriable || attempt >= maxAttempts) {
          throw error;
        }
        sleepSync(backoffMs(attempt));
        continue;
      }

      lastError = error instanceof Error ? error : new Error(String(error));
      if (attempt < maxAttempts && isTransientCurlError(error)) {
        log(`Webhook POST curl error; retrying after backoff`);
        sleepSync(backoffMs(attempt));
        continue;
      }
      throw lastError;
    }
  }

  throw (
    lastError ??
    new WebhookPostError('Webhook POST failed after all attempts', { attempt: maxAttempts })
  );
}
