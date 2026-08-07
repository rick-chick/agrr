import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import type { Page } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';
import { expect } from '@playwright/test';

export type A11yRoute = {
  pattern: string;
  url: string;
  requiresAuth: boolean;
};

export const a11yCoreRoutes: A11yRoute[] = [
  { pattern: '', url: '/', requiresAuth: false },
  { pattern: 'login', url: '/login', requiresAuth: false },
  { pattern: 'plans', url: '/plans', requiresAuth: true },
  { pattern: 'crops', url: '/crops', requiresAuth: true },
  { pattern: 'contact', url: '/contact', requiresAuth: false },
];

type AllowlistFile = {
  /** Known axe rule IDs allowed per route pattern (see a11y-allowlist.json). */
  routes: Record<string, { ruleId: string; reason: string }[]>;
};

export function loadA11yAllowlist(): AllowlistFile {
  const path = join(process.cwd(), 'e2e/smoke/a11y-allowlist.json');
  return JSON.parse(readFileSync(path, 'utf8')) as AllowlistFile;
}

export async function assertNoNewAxeViolations(page: Page, routePattern: string): Promise<void> {
  const allowlist = loadA11yAllowlist();
  const allowed = new Set((allowlist.routes[routePattern] ?? []).map((e) => e.ruleId));

  const results = await new AxeBuilder({ page }).analyze();
  const violations = results.violations.filter((v) => !allowed.has(v.id));

  if (violations.length > 0) {
    const summary = violations
      .map((v) => `${v.id}: ${v.help} (${v.nodes.length} nodes)`)
      .join('\n');
    expect(violations, `axe violations on route "${routePattern}":\n${summary}`).toHaveLength(0);
  }
}
