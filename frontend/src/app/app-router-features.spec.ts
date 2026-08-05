import { describe, it, expect } from 'vitest';
import { APP_ROUTER_SCROLL_OPTIONS } from './app-router-features';

describe('appRouterFeatures', () => {
  it('enables in-memory scroll position restoration and anchor scrolling', () => {
    expect(APP_ROUTER_SCROLL_OPTIONS).toEqual({
      scrollPositionRestoration: 'enabled',
      anchorScrolling: 'enabled'
    });
  });
});
