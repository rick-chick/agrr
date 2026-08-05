#!/usr/bin/env node
import { readFileSync, writeFileSync } from 'node:fs';
import { injectNoindexIntoHtml } from './inject-shell-noindex-lib.mjs';

const targetPath = process.argv[2];
if (!targetPath) {
  console.error('Usage: inject-shell-noindex-cli.mjs <html-file>');
  process.exit(1);
}

const html = readFileSync(targetPath, 'utf8');
writeFileSync(targetPath, injectNoindexIntoHtml(html));
