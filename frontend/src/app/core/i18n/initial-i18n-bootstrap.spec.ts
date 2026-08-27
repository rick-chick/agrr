import { describe, expect, it, vi } from 'vitest';
import { of, delay, tap, throwError } from 'rxjs';
import { TranslateService } from '@ngx-translate/core';
import { bootstrapAppI18n } from './initial-i18n-bootstrap';
import { I18N_BOOTSTRAP_FALLBACK } from './i18n-bootstrap-fallback';
import { I18nBootstrapStateService } from './i18n-bootstrap-state.service';

describe('bootstrapAppI18n', () => {
  it('registers langs and awaits translate.use before resolving', async () => {
    let useLoaded = false;
    const translate = {
      addLangs: vi.fn(),
      setDefaultLang: vi.fn(),
      setTranslation: vi.fn(),
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

  it('resolves with fallback translations when translate.use fails', async () => {
    const state = new I18nBootstrapStateService();
    const translate = {
      addLangs: vi.fn(),
      setDefaultLang: vi.fn(),
      setTranslation: vi.fn(),
      currentLang: '',
      use: vi.fn(() => throwError(() => new Error('network blocked'))),
    } as unknown as TranslateService;

    await expect(bootstrapAppI18n(translate, 'ja', state)).resolves.toBeUndefined();

    expect(translate.setTranslation).toHaveBeenCalledWith(
      'ja',
      I18N_BOOTSTRAP_FALLBACK.ja,
      true
    );
    expect(translate.currentLang).toBe('ja');
    expect(state.loadFailed()).toBe(true);
    expect(state.failedLang()).toBe('ja');
  });

  it('marks bootstrap state successful when translate.use succeeds', async () => {
    const state = new I18nBootstrapStateService();
    state.markFailed('ja');
    const translate = {
      addLangs: vi.fn(),
      setDefaultLang: vi.fn(),
      setTranslation: vi.fn(),
      currentLang: '',
      use: vi.fn(() => of({})),
    } as unknown as TranslateService;

    await bootstrapAppI18n(translate, 'ja', state);

    expect(state.loadFailed()).toBe(false);
    expect(state.failedLang()).toBeNull();
  });
});

describe('I18nBootstrapStateService', () => {
  it('clears failure state after successful retry', async () => {
    const state = new I18nBootstrapStateService();
    state.markFailed('ja');

    const translate = {
      currentLang: 'ja',
      use: vi.fn(() => of({})),
      setTranslation: vi.fn(),
    } as unknown as TranslateService;

    await state.retry(translate);

    expect(state.loadFailed()).toBe(false);
    expect(state.failedLang()).toBeNull();
  });

  it('keeps failure state when retry still fails', async () => {
    const state = new I18nBootstrapStateService();
    state.markFailed('ja');

    const translate = {
      currentLang: 'ja',
      use: vi.fn(() => throwError(() => new Error('still blocked'))),
      setTranslation: vi.fn(),
    } as unknown as TranslateService;

    await state.retry(translate);

    expect(state.loadFailed()).toBe(true);
    expect(state.failedLang()).toBe('ja');
    expect(translate.setTranslation).toHaveBeenCalled();
  });
});
