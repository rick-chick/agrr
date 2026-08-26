import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  expectedPathname,
  expectedPathnameFromResolvedGoto,
  normalizePathname,
  workCapturePathnameOk,
  onboardingCapturePathnameOk,
  resolveHostSelectorForPatternFromUrl,
} from './route-validity-lib.mjs';

const HOST_BY_PATTERN = {
  work: 'app-work-hub',
  onboarding: 'app-onboarding',
  plans: 'app-plan-list',
};

test('expectedPathname strips query and trailing slash', () => {
  assert.equal(
    expectedPathname({ pattern: 'x', url: '/plans/1/work?tab=today', requiresAuth: true, source: 't' }),
    '/plans/1/work',
  );
  assert.equal(
    expectedPathname({ pattern: 'x', url: 'about/', requiresAuth: false, source: 't' }),
    '/about',
  );
});

test('normalizePathname treats root slash as /', () => {
  assert.equal(normalizePathname('/'), '/');
  assert.equal(normalizePathname('/plans/1/'), '/plans/1');
});

test('expectedPathnameFromResolvedGoto normalizes relative href', () => {
  assert.equal(expectedPathnameFromResolvedGoto('plans/77/work'), '/plans/77/work');
  assert.equal(expectedPathnameFromResolvedGoto('/plans/77/work/'), '/plans/77/work');
});

test('workCapturePathnameOk accepts hub and single-farm auto-redirect', () => {
  assert.equal(workCapturePathnameOk('/work'), true);
  assert.equal(workCapturePathnameOk('/plans/1/work'), true);
  assert.equal(workCapturePathnameOk('/plans/'), false);
});

test('onboardingCapturePathnameOk accepts wizard and saved-plan redirect', () => {
  assert.equal(onboardingCapturePathnameOk('/onboarding'), true);
  assert.equal(onboardingCapturePathnameOk('/plans'), true);
  assert.equal(onboardingCapturePathnameOk('/plans/new'), false);
});

test('resolveHostSelectorForPatternFromUrl handles work and onboarding redirects', () => {
  assert.equal(
    resolveHostSelectorForPatternFromUrl('work', 'http://127.0.0.1:3000/work', HOST_BY_PATTERN),
    'app-work-hub',
  );
  assert.equal(
    resolveHostSelectorForPatternFromUrl('work', 'http://127.0.0.1:3000/plans/42/work', HOST_BY_PATTERN),
    'app-plan-work',
  );
  assert.equal(
    resolveHostSelectorForPatternFromUrl('onboarding', 'http://127.0.0.1:3000/onboarding', HOST_BY_PATTERN),
    'app-onboarding',
  );
  assert.equal(
    resolveHostSelectorForPatternFromUrl('onboarding', 'http://127.0.0.1:3000/plans', HOST_BY_PATTERN),
    'app-plan-list',
  );
  assert.equal(
    resolveHostSelectorForPatternFromUrl('plans', 'http://127.0.0.1:3000/plans', HOST_BY_PATTERN),
    'app-plan-list',
  );
});
