import { afterEach, describe, expect, it } from 'vitest';
import {
  dismissWeatherRescheduleProposal,
  filterActiveWeatherRescheduleProposals,
  readDismissedWeatherRescheduleProposalIds
} from './weather-reschedule-proposal-session';

describe('weather-reschedule-proposal-session', () => {
  afterEach(() => {
    sessionStorage.clear();
  });

  it('filters dismissed proposal ids for the plan session', () => {
    dismissWeatherRescheduleProposal(7, 'frost_forecast:1:0');
    expect(readDismissedWeatherRescheduleProposalIds(7)).toEqual(
      new Set(['frost_forecast:1:0'])
    );
    const active = filterActiveWeatherRescheduleProposals(7, [
      { id: 'frost_forecast:1:0' },
      { id: 'gdd_trajectory_delay:2:0' }
    ]);
    expect(active.map((p) => p.id)).toEqual(['gdd_trajectory_delay:2:0']);
  });
});
