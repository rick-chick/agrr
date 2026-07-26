/**
 * Static checks for issue #500: home initial bundle must not eagerly load Chart.js / gantt.
 */

const CHART_ADAPTER_IMPORT = /import\s+['"]chartjs-adapter-date-fns['"]/;
const STATIC_GANTT_IMPORT =
  /import\s+\{\s*PlanGanttClimateShellComponent\s*\}\s+from\s+['"][^'"]+plan-gantt-climate-shell\.component['"]/;
const DEFER_BLOCK = /@defer\b/;
const GANTT_SELECTOR = /<app-plan-gantt-climate-shell\b/;

/**
 * @param {string} appConfigSource
 * @returns {string[]}
 */
export function findAppConfigChartAdapterViolations(appConfigSource) {
  if (!CHART_ADAPTER_IMPORT.test(appConfigSource)) {
    return [];
  }
  return ['app.config.ts must not globally import chartjs-adapter-date-fns'];
}

/**
 * @param {string} homeDemoSource
 * @returns {string[]}
 */
export function findHomeDemoGanttLazyLoadViolations(homeDemoSource) {
  const violations = [];

  if (STATIC_GANTT_IMPORT.test(homeDemoSource) && !DEFER_BLOCK.test(homeDemoSource)) {
    violations.push(
      'home-demo-section.component.ts must defer PlanGanttClimateShellComponent (use @defer or dynamic import)'
    );
  }

  if (DEFER_BLOCK.test(homeDemoSource) && !GANTT_SELECTOR.test(homeDemoSource)) {
    violations.push('home-demo-section @defer block must render app-plan-gantt-climate-shell');
  }

  if (GANTT_SELECTOR.test(homeDemoSource) && !DEFER_BLOCK.test(homeDemoSource)) {
    violations.push('app-plan-gantt-climate-shell must only appear inside an @defer block');
  }

  return violations;
}

const ANSI_ESCAPE = /\x1b\[[0-9;]*m/g;

/**
 * @param {string} buildLog
 * @returns {number | null}
 */
export function parseInitialBundleRawKb(buildLog) {
  const plain = buildLog.replace(ANSI_ESCAPE, '');
  const match = plain.match(/Initial total\s*\|\s*([\d.]+)\s*kB/i);
  return match ? Number.parseFloat(match[1]) : null;
}

/**
 * @param {number} rawKb
 * @param {number} [budgetKb=700]
 * @returns {string[]}
 */
export function findInitialBundleBudgetViolations(rawKb, budgetKb = 700) {
  if (rawKb == null || Number.isNaN(rawKb)) {
    return ['could not parse initial bundle size from production build output'];
  }
  if (rawKb > budgetKb) {
    return [`initial bundle ${rawKb} kB exceeds ${budgetKb} kB warning budget`];
  }
  return [];
}
