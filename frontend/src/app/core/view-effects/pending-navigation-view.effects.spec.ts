import { vi } from 'vitest';
import { consumePendingNavigation } from './pending-navigation-view.effects';

describe('consumePendingNavigation', () => {
  it('navigates and clears pending request when set', () => {
    const navigate = vi.fn();
    const state = {
      pendingNavigation: {
        commands: ['/plans', 42],
        extras: { queryParams: { tab: 'work' } }
      }
    };

    const result = consumePendingNavigation(state, { router: { navigate } });

    expect(navigate).toHaveBeenCalledWith(['/plans', 42], { queryParams: { tab: 'work' } });
    expect(result.pendingNavigation).toBeNull();
  });

  it('returns state unchanged when pendingNavigation is null', () => {
    const navigate = vi.fn();
    const state = { pendingNavigation: null };

    const result = consumePendingNavigation(state, { router: { navigate } });

    expect(navigate).not.toHaveBeenCalled();
    expect(result).toBe(state);
  });
});
