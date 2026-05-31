import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';

const proxyFiles = ['proxy.conf.dev.cjs', 'proxy.conf.gcp-test.cjs'];

describe('ng serve proxy routes', () => {
  for (const file of proxyFiles) {
    it(`${file} proxies POST /undo_deletion to the API backend`, () => {
      const content = readFileSync(join(__dirname, file), 'utf8');
      expect(content).toMatch(/['"]\/undo_deletion['"]\s*:/);
    });
  }
});
