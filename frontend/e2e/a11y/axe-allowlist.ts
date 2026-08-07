import type { Result } from 'axe-core';

export type AxeAllowlistEntry = {
  id: string;
  targets?: string[];
};

export type AxeAllowlistFile = {
  violations: AxeAllowlistEntry[];
};

/**
 * Returns violations that are not fully covered by the allowlist.
 * Empty targets on an allowlist entry means the entire rule is known/accepted.
 */
export function filterAxeViolations(
  violations: Result[],
  allowlist: AxeAllowlistFile
): Result[] {
  return violations.filter((violation) => {
    const entry = allowlist.violations.find((row) => row.id === violation.id);
    if (!entry) {
      return true;
    }
    if (!entry.targets?.length) {
      return false;
    }

    const unmatchedNodes = violation.nodes.filter(
      (node) =>
        !entry.targets!.some((target) => node.target.join(' ').includes(target))
    );
    return unmatchedNodes.length > 0;
  });
}
