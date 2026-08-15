import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { describe, expect, it } from 'vitest';

describe('workRoutes', () => {
  it('registers work/variance before work and pins work hub to full path match', () => {
    const routesPath = join(dirname(fileURLToPath(import.meta.url)), 'work.routes.ts');
    const source = readFileSync(routesPath, 'utf8');
    const varianceIndex = source.indexOf("path: 'work/variance'");
    const hubIndex = source.indexOf("path: 'work',");
    expect(varianceIndex).toBeGreaterThanOrEqual(0);
    expect(hubIndex).toBeGreaterThanOrEqual(0);
    expect(varianceIndex).toBeLessThan(hubIndex);
    expect(source).toContain("pathMatch: 'full'");
  });
});
