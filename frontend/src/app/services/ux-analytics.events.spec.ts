import { describe, expect, it } from 'vitest';
import { recoveryFailureCategoryFromLoadError } from './ux-analytics.events';

describe('recoveryFailureCategoryFromLoadError', () => {
  it('maps not_found and warmup keys to distinct failure categories', () => {
    expect(recoveryFailureCategoryFromLoadError('common.api_error.not_found')).toBe('not_found');
    expect(recoveryFailureCategoryFromLoadError('common.backend_warmup.database')).toBe(
      'backend_warmup'
    );
    expect(recoveryFailureCategoryFromLoadError('common.backend_warmup.compute_engine')).toBe(
      'backend_warmup'
    );
  });

  it('falls back to default for other errors', () => {
    expect(recoveryFailureCategoryFromLoadError('common.api_error.generic')).toBe('default');
    expect(recoveryFailureCategoryFromLoadError(null)).toBe('default');
  });
});
