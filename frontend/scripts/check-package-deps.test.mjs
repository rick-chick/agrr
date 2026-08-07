import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  auditForbiddenPackageDependencies,
  findForbiddenDependencies,
} from './check-package-deps-lib.mjs';

test('findForbiddenDependencies reports forbidden packages in a section', () => {
  const deps = {
    '@angular/core': '^21.0.0',
    '@angular/material': '^21.0.0',
  };
  const violations = findForbiddenDependencies(deps, 'dependencies', ['@angular/material']);
  assert.deepEqual(violations, [{ packageName: '@angular/material', section: 'dependencies' }]);
});

test('auditForbiddenPackageDependencies rejects @angular/material in frontend package.json', async () => {
  const frontendRoot = new URL('..', import.meta.url).pathname;
  const violations = await auditForbiddenPackageDependencies(frontendRoot, ['@angular/material']);
  assert.deepEqual(violations, []);
});
