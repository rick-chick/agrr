import { describe, expect, it, vi } from 'vitest';

import {
  FATAL_ERROR_FALLBACK_ROOT_ID,
  renderFatalErrorFallback
} from './render-fatal-error-fallback';

describe('renderFatalErrorFallback', () => {
  it('renders bootstrap fallback with message and reload button', () => {
    const host = document.createElement('app-root');
    document.body.appendChild(host);

    renderFatalErrorFallback(host, { kind: 'bootstrap', lang: 'ja' });

    const root = host.querySelector(`#${FATAL_ERROR_FALLBACK_ROOT_ID}`);
    expect(root).not.toBeNull();
    expect(root?.getAttribute('role')).toBe('alert');
    expect(host.textContent).toContain('アプリを起動できませんでした');
    expect(host.textContent).toContain('再読み込み');

    const button = host.querySelector('button');
    expect(button).not.toBeNull();
    expect(button?.getAttribute('type')).toBe('button');

    host.remove();
  });

  it('renders runtime fallback with distinct message', () => {
    const host = document.createElement('app-root');
    document.body.appendChild(host);

    renderFatalErrorFallback(host, { kind: 'runtime', lang: 'ja' });

    expect(host.textContent).toContain('予期しないエラーが発生しました');
    expect(host.textContent).not.toContain('アプリを起動できませんでした');

    host.remove();
  });

  it('renders English runtime copy when lang is en', () => {
    const host = document.createElement('app-root');
    document.body.appendChild(host);

    renderFatalErrorFallback(host, { kind: 'runtime', lang: 'en' });

    expect(host.textContent).toContain('An unexpected error occurred');

    host.remove();
  });

  it('reload button calls window.location.reload', () => {
    const host = document.createElement('app-root');
    document.body.appendChild(host);
    const reload = vi.fn();
    const originalLocation = window.location;
    Object.defineProperty(window, 'location', {
      configurable: true,
      value: { ...originalLocation, reload }
    });

    try {
      renderFatalErrorFallback(host, { kind: 'runtime', lang: 'ja' });
      const button = host.querySelector('button');
      button?.dispatchEvent(new MouseEvent('click', { bubbles: true }));
      expect(reload).toHaveBeenCalledOnce();
    } finally {
      Object.defineProperty(window, 'location', {
        configurable: true,
        value: originalLocation
      });
      host.remove();
    }
  });
});
