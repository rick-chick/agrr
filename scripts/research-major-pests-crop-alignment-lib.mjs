/**
 * Detect major_pests report content that belongs to a different crop than the path slug.
 */

/** @type {Record<string, { forbidden: RegExp[]; required: RegExp[] }>} */
export const MAJOR_PESTS_CROP_ALIGNMENT = {
  cabbage: {
    forbidden: [
      /Major Onion Pests/i,
      /Onion \(Allium cepa\)/i,
      /世界における玉ねぎ/,
    ],
    required: [/\bcabbage\b/i, /キャベツ|きゃべつ/],
  },
  radish: {
    forbidden: [
      /Major Cabbage Pests/i,
      /Cabbage \(Brassica oleracea var\. capitata\)/i,
      /世界におけるキャベツ主要害虫/,
    ],
    required: [/\bradish\b/i, /raphanus/i, /大根|ラディッシュ/],
  },
};

/**
 * @param {string} crop
 * @param {string} text - Visible vp-doc plain text or HTML body.
 * @returns {string[]}
 */
export function findMajorPestsCropAlignmentIssues(crop, text) {
  const rule = MAJOR_PESTS_CROP_ALIGNMENT[crop];
  if (!rule) {
    return [];
  }

  const issues = [];
  for (const pattern of rule.forbidden) {
    if (pattern.test(text)) {
      issues.push(`forbidden crop mention for ${crop}: ${pattern}`);
    }
  }
  const hasRequired = rule.required.some((pattern) => pattern.test(text));
  if (!hasRequired) {
    issues.push(`missing expected crop mention for ${crop}`);
  }
  return issues;
}

/**
 * @param {string} title
 * @returns {string[]}
 */
export function findAwkwardEnTitleIssues(title) {
  const issues = [];
  if (/gdd-requirements|cumulative temperature-gdd/i.test(title)) {
    issues.push('awkward machine-translated title');
  }
  return issues;
}
