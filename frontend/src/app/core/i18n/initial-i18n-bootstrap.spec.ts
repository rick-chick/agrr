import { describe, expect, it, vi } from 'vitest';
import { of, delay, tap } from 'rxjs';
import { TranslateService } from '@ngx-translate/core';
import { bootstrapAppI18n } from './initial-i18n-bootstrap';

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
});
