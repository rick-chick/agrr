/**
 * Pure layout contract coverage checks (unit-tested).
 */

/** @typedef {'master-list' | 'wizard-step' | 'l1-only'} LayoutArchetype */

/**
 * @param {object} input
 * @param {string[]} input.manifestPatterns
 * @param {Record<string, LayoutArchetype>} input.bindings
 * @param {Record<string, string>} input.exempt
 * @param {readonly LayoutArchetype[]} input.archetypes
 */
export function checkLayoutContractCoverage({
  manifestPatterns,
  bindings,
  exempt,
  archetypes,
}) {
  const missing = [];
  const unknownArchetypes = [];

  for (const pattern of manifestPatterns) {
    if (exempt[pattern]) {
      continue;
    }
    const archetype = bindings[pattern];
    if (!archetype) {
      missing.push(pattern);
      continue;
    }
    if (!archetypes.includes(archetype)) {
      unknownArchetypes.push({ pattern, archetype });
    }
  }

  const manifestSet = new Set(manifestPatterns);
  const extraBindings = Object.keys(bindings).filter((pattern) => !manifestSet.has(pattern));
  const extraExempt = Object.keys(exempt).filter((pattern) => !manifestSet.has(pattern));

  return {
    ok:
      missing.length === 0 &&
      unknownArchetypes.length === 0 &&
      extraBindings.length === 0 &&
      extraExempt.length === 0,
    missing,
    unknownArchetypes,
    extraBindings,
    extraExempt,
    manifestCount: manifestPatterns.length,
    bindingCount: Object.keys(bindings).length,
    exemptCount: Object.keys(exempt).length,
  };
}

/**
 * @param {LayoutArchetype} archetype
 * @param {Record<string, (page: unknown, hostSelector: string) => Promise<void>>} runners
 */
export function assertArchetypeRunnerRegistered(archetype, runners) {
  if (archetype === 'l1-only') {
    return { ok: true, reason: null };
  }
  if (typeof runners[archetype] === 'function') {
    return { ok: true, reason: null };
  }
  return { ok: false, reason: `missing L2 runner for archetype "${archetype}"` };
}

/**
 * @param {Record<string, LayoutArchetype>} bindings
 * @param {Record<string, (page: unknown, hostSelector: string) => Promise<void>>} runners
 */
export function findMissingArchetypeRunners(bindings, runners) {
  const used = new Set(Object.values(bindings));
  /** @type {string[]} */
  const missing = [];
  for (const archetype of used) {
    const result = assertArchetypeRunnerRegistered(archetype, runners);
    if (!result.ok) {
      missing.push(archetype);
    }
  }
  return missing;
}
