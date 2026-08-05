import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { describe, expect, it } from 'vitest';

const appRoot = dirname(fileURLToPath(import.meta.url));

const appConfigSource = readFileSync(join(appRoot, 'app.config.ts'), 'utf8');
const coreRoutesSource = readFileSync(join(appRoot, 'routes/core.routes.ts'), 'utf8');

describe('app router configuration', () => {
  it('enables in-memory scroll position restoration and anchor scrolling', () => {
    expect(appConfigSource).toMatch(/withInMemoryScrolling\s*\(/);
    expect(appConfigSource).toMatch(/scrollPositionRestoration:\s*'enabled'/);
    expect(appConfigSource).toMatch(/anchorScrolling:\s*'enabled'/);
  });

  it('redirects legacy /dashboard to home instead of duplicating HomeComponent', () => {
    expect(coreRoutesSource).toMatch(
      /path:\s*'dashboard'[\s\S]*redirectTo:\s*['"]\/['"]/
    );
    expect(coreRoutesSource).not.toMatch(
      /path:\s*'dashboard'[\s\S]*component:\s*HomeComponent/
    );
  });
});
