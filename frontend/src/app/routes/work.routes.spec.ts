import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { describe, expect, it } from 'vitest';

describe('workRoutes', () => {
  it('defines variance as a child route under work', () => {
    const routesPath = join(dirname(fileURLToPath(import.meta.url)), 'work.routes.ts');
    const source = readFileSync(routesPath, 'utf8');
    expect(source).toContain("path: 'work'");
    expect(source).toContain("path: 'variance'");
    expect(source.indexOf("path: 'variance'")).toBeGreaterThan(source.indexOf('children:'));
  });
});
