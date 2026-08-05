#!/usr/bin/env node
import { readFileSync } from 'node:fs';
import { extractHreflangLinks, canonicalMatches } from './verify-seo-canonical-lib.mjs';

const [command, ...rest] = process.argv.slice(2);

if (command === 'check') {
  const [html, expectedJa, expectedEn] = rest;
  const links = extractHreflangLinks(html ?? '');
  const ja = links.find((link) => link.hreflang === 'ja');
  const en = links.find((link) => link.hreflang === 'en');
  const xDefault = links.find((link) => link.hreflang === 'x-default');

  if (!ja || !canonicalMatches(ja.href, expectedJa)) {
    console.error(`missing or mismatched hreflang=ja (expected ${expectedJa}, got ${ja?.href ?? 'none'})`);
    process.exit(1);
  }
  if (!en || !canonicalMatches(en.href, expectedEn)) {
    console.error(`missing or mismatched hreflang=en (expected ${expectedEn}, got ${en?.href ?? 'none'})`);
    process.exit(1);
  }
  if (!xDefault || !canonicalMatches(xDefault.href, expectedJa)) {
    console.error(`missing or mismatched hreflang=x-default (expected ${expectedJa}, got ${xDefault?.href ?? 'none'})`);
    process.exit(1);
  }
  process.stdout.write('OK');
  process.exit(0);
}

if (command === 'check-file') {
  const html = readFileSync(rest[0], 'utf8');
  process.argv = [process.argv[0], process.argv[1], 'check', html, rest[1], rest[2]];
}

console.error('Usage: verify-seo-hreflang-cli.mjs check <html> <expectedJa> <expectedEn>');
process.exit(1);
