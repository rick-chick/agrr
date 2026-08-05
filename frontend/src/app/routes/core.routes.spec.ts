import { describe, it, expect } from 'vitest';
import { coreRoutes } from './core.routes';

describe('coreRoutes', () => {
  it('redirects legacy /dashboard to home', () => {
    const dashboard = coreRoutes.find((route) => route.path === 'dashboard');
    expect(dashboard).toEqual({
      path: 'dashboard',
      redirectTo: '',
      pathMatch: 'full'
    });
  });
});
