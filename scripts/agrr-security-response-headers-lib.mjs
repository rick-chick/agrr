/**
 * Canonical security response headers for agrr.net (LB backend buckets/services + agrr-server).
 * Keep in sync with crates/agrr-server/src/security_headers.rs RESPONSE_HEADERS.
 */

import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

/** @type {readonly string[]} */
export const SECURITY_RESPONSE_HEADERS = [
  'Strict-Transport-Security: max-age=31536000; includeSubDomains',
  'X-Content-Type-Options: nosniff',
  'Referrer-Policy: strict-origin-when-cross-origin',
  'X-Frame-Options: DENY',
  "Content-Security-Policy-Report-Only: default-src 'self'; script-src 'self' 'unsafe-inline' https://www.googletagmanager.com https://www.google-analytics.com; connect-src 'self' https://www.google-analytics.com https://region1.google-analytics.com https://www.googletagmanager.com; img-src 'self' data: https://www.google-analytics.com https://www.googletagmanager.com; style-src 'self' 'unsafe-inline'; frame-ancestors 'none'",
];

/** @type {readonly { kind: 'backend-bucket' | 'backend-service', name: string }[]} */
export const SECURITY_HEADER_TARGETS = [
  { kind: 'backend-bucket', name: 'agrr-frontend-backend' },
  { kind: 'backend-bucket', name: 'agrr-research-backend' },
  { kind: 'backend-service', name: 'rust-backend' },
];

const REQUIRED_HEADER_PREFIXES = [
  'Strict-Transport-Security:',
  'X-Content-Type-Options:',
  'Referrer-Policy:',
  'X-Frame-Options:',
  'Content-Security-Policy-Report-Only:',
];

/**
 * @param {string} repoRoot
 * @returns {{ ok: boolean, errors: string[] }}
 */
export function verifyAgrrSecurityResponseHeaders(repoRoot) {
  const errors = [];

  const libPath = join(repoRoot, 'scripts/agrr-security-response-headers-lib.mjs');
  const rustPath = join(repoRoot, 'crates/agrr-server/src/security_headers.rs');
  const applyPath = join(repoRoot, 'scripts/apply-agrr-security-response-headers.sh');

  if (!existsSync(libPath)) {
    errors.push(`missing ${libPath}`);
  }
  if (!existsSync(rustPath)) {
    errors.push(`missing ${rustPath}`);
  }
  if (!existsSync(applyPath)) {
    errors.push(`missing ${applyPath}`);
  }

  for (const header of SECURITY_RESPONSE_HEADERS) {
    const matched = REQUIRED_HEADER_PREFIXES.some((prefix) => header.startsWith(prefix));
    if (!matched) {
      errors.push(`unexpected header entry: ${header}`);
    }
  }

  for (const prefix of REQUIRED_HEADER_PREFIXES) {
    const found = SECURITY_RESPONSE_HEADERS.some((header) => header.startsWith(prefix));
    if (!found) {
      errors.push(`missing header with prefix ${prefix}`);
    }
  }

  if (existsSync(rustPath)) {
    const rustSource = readFileSync(rustPath, 'utf8');
    for (const token of [
      'strict-transport-security',
      'x-content-type-options',
      'referrer-policy',
      'x-frame-options',
      'content-security-policy-report-only',
    ]) {
      if (!rustSource.includes(token)) {
        errors.push(`rust security_headers.rs missing ${token}`);
      }
    }
  }

  if (existsSync(applyPath)) {
    const applySource = readFileSync(applyPath, 'utf8');
    for (const target of SECURITY_HEADER_TARGETS) {
      if (!applySource.includes(target.name)) {
        errors.push(`apply script missing target ${target.name}`);
      }
    }
  }

  return { ok: errors.length === 0, errors };
}
