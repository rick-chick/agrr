import { expect, type Page } from '@playwright/test';

export async function readWizardProgressSnapshot(page: Page) {
  const shell = page.locator('app-funnel-shell');
  await expect(shell).toBeVisible();
  await expect(shell.locator('.funnel-shell-header--wizard')).toBeVisible();
  const progress = shell.locator('[data-testid="wizard-progress"]');
  await expect(progress).toBeVisible();

  const steps = progress.locator('.compact-step');
  const stepCount = await steps.count();
  const activeIndex = await steps.evaluateAll((nodes) =>
    nodes.findIndex((node) => node.classList.contains('active')),
  );
  const completedCount = await steps.evaluateAll(
    (nodes) => nodes.filter((node) => node.classList.contains('completed')).length,
  );
  const linkHrefs = await progress.locator('a.step-label-link').evaluateAll((anchors) =>
    anchors.map((anchor) => anchor.getAttribute('href')),
  );

  return { stepCount, activeIndex, completedCount, linkHrefs };
}

export async function assertWizardProgressParity(
  publicPlanPage: Page,
  entrySchedulePage: Page,
  options: { publicPlanActiveIndex: number; entryScheduleActiveIndex: number },
) {
  const publicPlan = await readWizardProgressSnapshot(publicPlanPage);
  const entrySchedule = await readWizardProgressSnapshot(entrySchedulePage);

  expect(publicPlan.stepCount).toBe(2);
  expect(entrySchedule.stepCount).toBe(2);
  expect(publicPlan.stepCount).toBe(entrySchedule.stepCount);
  expect(publicPlan.activeIndex).toBe(options.publicPlanActiveIndex);
  expect(entrySchedule.activeIndex).toBe(options.entryScheduleActiveIndex);
}
