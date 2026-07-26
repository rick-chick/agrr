import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { describe, expect, it } from 'vitest';

const homeDir = dirname(fileURLToPath(import.meta.url));
const appRoot = join(homeDir, '../..');

const homeDemoSource = readFileSync(join(homeDir, 'home-demo-section.component.ts'), 'utf8');
const loaderSource = readFileSync(join(homeDir, 'home-demo-gantt-shell.loader.ts'), 'utf8');
const appConfigSource = readFileSync(join(appRoot, 'app.config.ts'), 'utf8');

describe('home bundle boundaries', () => {
  it('does not statically import PlanGanttClimateShellComponent in HomeDemoSectionComponent', () => {
    expect(homeDemoSource).not.toMatch(
      /import\s*\{[^}]*PlanGanttClimateShellComponent[^}]*\}\s*from\s*['"]\.\.\/plans\/plan-gantt-climate-shell\.component['"]/
    );
    expect(homeDemoSource).toMatch(/LOAD_HOME_DEMO_GANTT_SHELL/);
  });

  it('lazy-loads PlanGanttClimateShell via dynamic import in loader', () => {
    expect(loaderSource).toMatch(/import\s*\(\s*['"]\.\.\/plans\/plan-gantt-climate-shell\.component['"]\s*\)/);
  });

  it('does not register chartjs-adapter-date-fns globally in app.config.ts', () => {
    expect(appConfigSource).not.toMatch(/chartjs-adapter-date-fns/);
  });
});
