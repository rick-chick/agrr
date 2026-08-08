import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { describe, expect, it } from 'vitest';

const routesDir = dirname(fileURLToPath(import.meta.url));
const appRoot = join(routesDir, '..');

const plansRoutesSource = readFileSync(join(routesDir, 'plans.routes.ts'), 'utf8');
const workRoutesSource = readFileSync(join(routesDir, 'work.routes.ts'), 'utf8');
const appRoutesSource = readFileSync(join(appRoot, 'app.routes.ts'), 'utf8');
const planListSource = readFileSync(
  join(appRoot, 'components/plans/plan-list.component.ts'),
  'utf8',
);
const workHubSource = readFileSync(
  join(appRoot, 'components/work-hub/work-hub.component.ts'),
  'utf8',
);
const angularJson = readFileSync(join(appRoot, '../../angular.json'), 'utf8');

/** Lighthouse CI authenticated routes must stay out of the initial bundle until navigated. */
describe('perf bundle boundaries (Lighthouse CI authenticated routes)', () => {
  it('lazy-loads /plans, /plans/:id, and /work via loadComponent in route modules', () => {
    expect(plansRoutesSource).toMatch(
      /path:\s*'plans\/:id'[\s\S]*?loadComponent:\s*\(\)\s*=>/,
    );
    expect(plansRoutesSource).toMatch(/path:\s*'plans'[\s\S]*?loadComponent:\s*\(\)\s*=>/);
    expect(workRoutesSource).toMatch(/path:\s*'work'[\s\S]*?loadComponent:\s*\(\)\s*=>/);
  });

  it('does not statically import gantt or chart modules in plan-list (Lighthouse /plans route)', () => {
    expect(planListSource).not.toMatch(/gantt-chart\.component/);
    expect(planListSource).not.toMatch(/plan-gantt-climate-shell\.component/);
    expect(planListSource).not.toMatch(/chart\.js/);
    expect(planListSource).not.toMatch(/leaflet/);
  });

  it('does not statically import chart.js or leaflet in work-hub (Lighthouse /work route)', () => {
    expect(workHubSource).not.toMatch(/chart\.js/);
    expect(workHubSource).not.toMatch(/leaflet/);
    expect(workHubSource).not.toMatch(/gantt-chart\.component/);
  });

  it('keeps app.routes.ts free of static plan-detail or gantt imports', () => {
    expect(appRoutesSource).not.toMatch(/plan-detail\.component/);
    expect(appRoutesSource).not.toMatch(/gantt-chart\.component/);
    expect(appRoutesSource).not.toMatch(/plan-gantt-climate-shell\.component/);
  });

  it('defines an initial bundle budget in angular.json for regression detection', () => {
    expect(angularJson).toMatch(/"type":\s*"initial"/);
    expect(angularJson).toMatch(/"maximumWarning":\s*"700kB"/);
  });
});
