#!/usr/bin/env node
import { readFileSync } from 'node:fs';
import {
  extractCanonicalHref,
  extractHreflangAlternates,
  hreflangAlternateMatches,
} from './verify-seo-canonical-lib.mjs';

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

if (command === 'verify-hreflang') {
  const [html, jaUrl, enUrl] = rest;
  const alternates = extractHreflangAlternates(html ?? '');
  const ok =
    hreflangAlternateMatches(alternates, 'ja', jaUrl) &&
    hreflangAlternateMatches(alternates, 'en', enUrl) &&
    hreflangAlternateMatches(alternates, 'x-default', jaUrl);
  process.exit(ok ? 0 : 1);
}

console.error('Usage: verify-seo-canonical-cli.mjs extract <html>');
console.error('       verify-seo-canonical-cli.mjs extract-file <path>');
console.error('       verify-seo-canonical-cli.mjs verify-hreflang <html> <jaUrl> <enUrl>');
process.exit(1);
