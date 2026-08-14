import { describe, expect, it } from 'vitest';
import {
  resolveWorkRowGddContext,
  resolveWorkRowGddTrigger,
  resolveWorkRowWeatherDependency,
  shouldShowWorkRowGddProgress
} from './resolve-work-row-context-badges';

describe('resolveWorkRowGddTrigger', () => {
  it('reads trigger from item field', () => {
    expect(resolveWorkRowGddTrigger({ gdd_trigger: '120', details: { gdd: { trigger: '0', tolerance: '0' } } as never })).toBe(120);
  });

  it('falls back to details.gdd.trigger', () => {
    expect(
      resolveWorkRowGddTrigger({
        gdd_trigger: '',
        details: { gdd: { trigger: '80', tolerance: '0' } } as never
      })
    ).toBe(80);
  });

  it('returns null when trigger is missing', () => {
    expect(resolveWorkRowGddTrigger({ gdd_trigger: '', details: { gdd: { trigger: '', tolerance: '' } } as never })).toBeNull();
  });
});

describe('resolveWorkRowGddContext', () => {
  it('returns trigger_only when cumulative GDD is unavailable', () => {
    expect(
      resolveWorkRowGddContext({
        gdd_trigger: '100',
        gdd_at_actual: null,
        gdd_delta: null,
        details: { gdd: { trigger: '100', tolerance: '0' } } as never
      })
    ).toEqual({ trigger: 100, state: 'trigger_only' });
  });

  it('returns reached when cumulative GDD meets or exceeds trigger', () => {
    expect(
      resolveWorkRowGddContext({
        gdd_trigger: '100',
        gdd_at_actual: 120,
        gdd_delta: 20,
        details: { gdd: { trigger: '100', tolerance: '0' } } as never
      })
    ).toEqual({ trigger: 100, state: 'reached', gddAtActual: 120 });
  });

  it('returns remaining when cumulative GDD is below trigger', () => {
    expect(
      resolveWorkRowGddContext({
        gdd_trigger: '100',
        gdd_at_actual: 85.5,
        gdd_delta: -14.5,
        details: { gdd: { trigger: '100', tolerance: '0' } } as never
      })
    ).toEqual({
      trigger: 100,
      state: 'remaining',
      remaining: 14.5,
      gddAtActual: 85.5
    });
  });
});

describe('shouldShowWorkRowGddProgress', () => {
  it('hides progress when GDD exceedance badge is shown', () => {
    expect(
      shouldShowWorkRowGddProgress({ trigger: 100, state: 'reached', gddAtActual: 120 }, true)
    ).toBe(false);
  });

  it('shows progress for reached state without exceedance badge', () => {
    expect(
      shouldShowWorkRowGddProgress({ trigger: 100, state: 'reached', gddAtActual: 120 }, false)
    ).toBe(true);
  });

  it('shows progress for remaining state without exceedance badge', () => {
    expect(
      shouldShowWorkRowGddProgress(
        { trigger: 100, state: 'remaining', remaining: 10, gddAtActual: 90 },
        false
      )
    ).toBe(true);
  });

  it('does not show progress for trigger_only state', () => {
    expect(shouldShowWorkRowGddProgress({ trigger: 100, state: 'trigger_only' }, false)).toBe(false);
  });
});

describe('resolveWorkRowWeatherDependency', () => {
  it('returns normalized weather dependency when present', () => {
    expect(
      resolveWorkRowWeatherDependency({
        weather_dependency: 'High',
        details: { weather_dependency: 'low' } as never
      })
    ).toBe('high');
  });

  it('falls back to details.weather_dependency', () => {
    expect(
      resolveWorkRowWeatherDependency({
        weather_dependency: '',
        details: { weather_dependency: 'medium' } as never
      })
    ).toBe('medium');
  });

  it('returns null for empty or none values', () => {
    expect(
      resolveWorkRowWeatherDependency({
        weather_dependency: 'none',
        details: { weather_dependency: '' } as never
      })
    ).toBeNull();
  });
});
