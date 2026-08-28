import { describe, expect, it } from 'vitest';

import { renderBootstrapFailureFallback } from './bootstrap-failure-fallback';

describe('renderBootstrapFailureFallback', () => {
  it('renders message and reload button into the host element', () => {
    const host = document.createElement('app-root');
    renderBootstrapFailureFallback(host);

    expect(host.querySelector('.app-error-fallback')).toBeTruthy();
    expect(host.querySelector('.page-title')?.textContent).toContain('起動に失敗');
    expect(host.querySelector('.page-section-content')?.textContent).toContain('再読み込み');
    expect(host.querySelector('button.btn-primary')?.textContent).toContain('再読み込み');
  });
});
