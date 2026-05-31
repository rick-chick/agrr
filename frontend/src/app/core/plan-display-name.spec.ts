import { describe, expect, it } from 'vitest';

import { localizePlanDisplayName } from './plan-display-name';

describe('localizePlanDisplayName', () => {
  const instant = (key: string, params?: Record<string, string>) => {
    if (key === 'plans.display_name_from_farm' && params?.['farmName']) {
      return `[plan] ${params['farmName']}`;
    }
    return key;
  };

  it('rewrites stored Japanese farm plan suffix for current locale', () => {
    const result = localizePlanDisplayName('Ahmedabad, Gujaratの計画', instant);
    expect(result).toBe('[plan] Ahmedabad, Gujarat');
  });

  it('rewrites suffix before a legacy year parenthetical', () => {
    const result = localizePlanDisplayName('Ahmedabad, Gujaratの計画 (2024)', instant);
    expect(result).toBe('[plan] Ahmedabad, Gujarat (2024)');
  });

  it('returns custom plan names unchanged', () => {
    const result = localizePlanDisplayName('Main Plan', instant);
    expect(result).toBe('Main Plan');
  });

  it('returns empty string for blank input', () => {
    expect(localizePlanDisplayName('  ', instant)).toBe('');
  });
});
