#!/usr/bin/env node
import { writeFileSync } from 'node:fs';

import { buildProfileSnippet } from './cloud-gh-auth-lib.mjs';

const target = process.argv[2];
if (!target) {
  console.error('usage: write-cloud-gh-auth-profile.mjs <path>');
  process.exit(2);
}

writeFileSync(target, buildProfileSnippet(), { encoding: 'utf8', mode: 0o644 });
