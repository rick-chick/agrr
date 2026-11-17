import { formatEntrySchedulePredictionGeneratedAt } from './entry-schedule-prediction-generated-at';

describe('formatEntrySchedulePredictionGeneratedAt', () => {
  it('formats RFC3339 timestamps for display (first 16 chars)', () => {
    expect(formatEntrySchedulePredictionGeneratedAt('2026-01-01T00:00:00Z')).toBe('2026-01-01T00:00');
  });

  it('converts UNIX seconds in a numeric string to the same display shape', () => {
    expect(formatEntrySchedulePredictionGeneratedAt('1700000000')).toBe('2023-11-14T22:13');
  });

  it('does not echo raw UNIX second digits when value is only digits', () => {
    const formatted = formatEntrySchedulePredictionGeneratedAt('1788855795');
    expect(formatted).toMatch(/^20\d{2}-\d{2}-\d{2}T\d{2}:\d{2}$/);
  });
});