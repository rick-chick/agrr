#!/usr/bin/env node
import { readFileSync } from 'node:fs';
import { extractCanonicalHref } from './verify-seo-canonical-lib.mjs';

const [command, ...rest] = process.argv.slice(2);

if (command === 'extract') {
  const html = rest[0] ?? '';
  const href = extractCanonicalHref(html);
  if (href) {
    process.stdout.write(href);
  }
  process.exit(0);
}

if (command === 'extract-file') {
  const href = extractCanonicalHref(readFileSync(rest[0], 'utf8'));
  if (href) {
    process.stdout.write(href);
  }
  process.exit(0);
}

console.error('Usage: verify-seo-canonical-lib.mjs extract <html>');
console.error('       verify-seo-canonical-lib.mjs extract-file <path>');
process.exit(1);
