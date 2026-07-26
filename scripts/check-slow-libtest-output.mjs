/**
 * Parse libtest `--report-time` output and detect tests exceeding a threshold.
 */

const DEFAULT_THRESHOLD_SEC = 0.5;

/**
 * @param {string} output
 * @param {{ thresholdSec?: number }} [options]
 * @returns {{ slow: Array<{ name: string; seconds: number }>; thresholdSec: number }}
 */
export function parseSlowLibtestOutput(output, options = {}) {
  const thresholdSec = options.thresholdSec ?? DEFAULT_THRESHOLD_SEC;
  /** @type {Array<{ name: string; seconds: number }>} */
  const slow = [];

  for (const line of output.split('\n')) {
    const match = line.match(/^test\s+(\S+)\s+\.\.\.\s+ok\s+([\d.]+)s\s*$/);
    if (!match) {
      continue;
    }
    const seconds = Number(match[2]);
    if (seconds > thresholdSec) {
      slow.push({ name: match[1], seconds });
    }
  }

  return { slow, thresholdSec };
}

/**
 * @param {string} output
 * @param {{ thresholdSec?: number }} [options]
 * @returns {{ ok: true } | { ok: false; message: string; slow: Array<{ name: string; seconds: number }> }}
 */
export function checkSlowLibtestOutput(output, options = {}) {
  const { slow, thresholdSec } = parseSlowLibtestOutput(output, options);
  if (slow.length === 0) {
    return { ok: true };
  }
  const details = slow
    .map(({ name, seconds }) => `  - ${name}: ${seconds.toFixed(3)}s`)
    .join('\n');
  const message = `=== Slow tests detected (threshold: ${thresholdSec}s) ===\n${details}`;
  return { ok: false, message, slow };
}
