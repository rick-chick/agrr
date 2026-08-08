import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { test } from 'node:test';

const __dirname = dirname(fileURLToPath(import.meta.url));
const appRoot = join(__dirname, '../src/app');

const HEAVY_IMPORT_PATTERNS = [
  /PlanGanttClimateShellComponent/,
  /gantt-chart\.component/,
  /chart\.js/,
  /['"]leaflet['"]/,
];

/**
 * @param {string} source
 * @param {string} label
 */
function assertNoHeavyStaticImports(source, label) {
  const importLines = source.split('\n').filter((line) => /^\s*import\s/.test(line));
  for (const line of importLines) {
    for (const pattern of HEAVY_IMPORT_PATTERNS) {
      assert.ok(
        !pattern.test(line),
        `${label} must not statically import heavy perf dependency via: ${line.trim()}`,
      );
    }
  }
}

test('plan-list route component avoids gantt/chart/leaflet static imports', () => {
  const source = readFileSync(
    join(appRoot, 'components/plans/plan-list.component.ts'),
    'utf8',
  );
  assertNoHeavyStaticImports(source, 'plan-list.component.ts');
});

test('work-hub route component avoids gantt/chart/leaflet static imports', () => {
  const source = readFileSync(
    join(appRoot, 'components/work-hub/work-hub.component.ts'),
    'utf8',
  );
  assertNoHeavyStaticImports(source, 'work-hub.component.ts');
});

test('plans.routes lazy-loads plan-detail (gantt) separately from plan-list', () => {
  const source = readFileSync(join(appRoot, 'routes/plans.routes.ts'), 'utf8');
  assert.match(source, /path:\s*'plans',\s*\n\s*loadComponent/);
  assert.match(source, /path:\s*'plans\/:id',\s*\n\s*loadComponent/);
  assert.match(source, /plan-detail\.component/);
  assert.match(source, /plan-list\.component/);
});
