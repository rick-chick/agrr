#!/usr/bin/env node
import { readFileSync } from 'node:fs';
import { checkSlowLibtestOutput } from './check-slow-libtest-output.mjs';

const logPath = process.argv[2];
if (!logPath) {
  console.error('usage: check-slow-libtest-output-cli.mjs <libtest-log>');
  process.exit(2);
}

const output = readFileSync(logPath, 'utf8');
const result = checkSlowLibtestOutput(output);
if (result.ok) {
  process.exit(0);
}

console.error(result.message);
process.exit(1);
