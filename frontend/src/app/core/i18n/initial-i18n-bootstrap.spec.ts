import { describe, expect, it, vi } from 'vitest';
import { of, delay, tap, throwError } from 'rxjs';
import { TranslateService } from '@ngx-translate/core';
import { bootstrapAppI18n } from './initial-i18n-bootstrap';
import { getI18nBootstrapFallback } from './i18n-bootstrap-fallback';
import type { I18nBootstrapStatePort } from './i18n-bootstrap-state.port';

describe('bootstrapAppI18n', () => {
  it('registers langs and awaits translate.use before resolving', async () => {
    let useLoaded = false;
    const translate = {
      addLangs: vi.fn(),
      setDefaultLang: vi.fn(),
      currentLang: '',
      use: vi.fn(() =>
        of({ 'home.index.hero.title': 'loaded' }).pipe(
          delay(5),
          tap(() => {
            useLoaded = true;
          })
        )
      ),
    } as unknown as TranslateService;

    expect(useLoaded).toBe(false);
    await bootstrapAppI18n(translate);

    expect(translate.addLangs).toHaveBeenCalledWith(['ja', 'en', 'in']);
    expect(translate.setDefaultLang).toHaveBeenCalledWith('ja');
    expect(translate.use).toHaveBeenCalled();
    expect(useLoaded).toBe(true);
  });

  it('applies fallback translations and marks failure when translate.use errors', async () => {
    const state: I18nBootstrapStatePort = {
      markFailed: vi.fn(),
      markSuccess: vi.fn(),
      markRetrying: vi.fn()
    };
    const translate = {
      addLangs: vi.fn(),
      setDefaultLang: vi.fn(),
      setTranslation: vi.fn(),
      currentLang: '',
      use: vi.fn(() => throwError(() => new Error('network error')))
    } as unknown as TranslateService;

    await expect(bootstrapAppI18n(translate, { lang: 'ja', state })).resolves.toBeUndefined();

    expect(translate.setTranslation).toHaveBeenCalledWith(
      'ja',
      getI18nBootstrapFallback('ja'),
      true
    );
    expect(state.markFailed).toHaveBeenCalled();
    expect(state.markSuccess).not.toHaveBeenCalled();
  });

  it('marks success when translate.use succeeds', async () => {
    const state: I18nBootstrapStatePort = {
      markFailed: vi.fn(),
      markSuccess: vi.fn(),
      markRetrying: vi.fn()
    };
    const translate = {
      addLangs: vi.fn(),
      setDefaultLang: vi.fn(),
      currentLang: '',
      use: vi.fn(() => of({}))
    } as unknown as TranslateService;

    await bootstrapAppI18n(translate, { lang: 'ja', state });

    expect(state.markSuccess).toHaveBeenCalled();
    expect(state.markFailed).not.toHaveBeenCalled();
  });
});
