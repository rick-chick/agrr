import { readFile } from 'node:fs/promises';
import { join } from 'node:path';

/** @typedef {{ packageName: string, section: string }} ForbiddenDependencyViolation */

/**
 * @param {Record<string, string>} deps
 * @param {string} section
 * @param {readonly string[]} forbidden
 * @returns {ForbiddenDependencyViolation[]}
 */
export function findForbiddenDependencies(deps, section, forbidden) {
  /** @type {ForbiddenDependencyViolation[]} */
  const violations = [];
  for (const packageName of forbidden) {
    if (packageName in deps) {
      violations.push({ packageName, section });
    }
  }
  return violations;
}

/**
 * @param {string} frontendRoot
 * @param {readonly string[]} forbidden
 * @returns {Promise<ForbiddenDependencyViolation[]>}
 */
export async function auditForbiddenPackageDependencies(frontendRoot, forbidden) {
  const packageJsonPath = join(frontendRoot, 'package.json');
  const raw = await readFile(packageJsonPath, 'utf8');
  const pkg = JSON.parse(raw);

  return [
    ...findForbiddenDependencies(pkg.dependencies ?? {}, 'dependencies', forbidden),
    ...findForbiddenDependencies(pkg.devDependencies ?? {}, 'devDependencies', forbidden),
  ];
}
