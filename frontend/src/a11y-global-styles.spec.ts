import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';

describe('global a11y styles', () => {
  const stylesPath = join(process.cwd(), 'src/styles.css');
  const styles = readFileSync(stylesPath, 'utf8');

  it('includes prefers-reduced-motion rules that shorten motion globally', () => {
    expect(styles).toMatch(/@media\s*\(\s*prefers-reduced-motion:\s*reduce\s*\)/);
    expect(styles).toMatch(/transition-duration:\s*0\.01ms/);
    expect(styles).toMatch(/\.btn:hover:not\(:disabled\)/);
    expect(styles).toMatch(/transform:\s*none/);
  });
});
