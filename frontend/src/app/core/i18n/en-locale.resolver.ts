import { inject } from '@angular/core';
import { ResolveFn } from '@angular/router';
import { TranslateService } from '@ngx-translate/core';
import { firstValueFrom } from 'rxjs';
import { applyAppLang } from '../app-locale';

/** Switches ngx-translate to English before EN prerender / navigation. */
export const enLocaleResolver: ResolveFn<void> = async () => {
  const translate = inject(TranslateService);
  applyAppLang(translate, 'en', { persist: false });
  if (typeof document !== 'undefined') {
    document.documentElement.lang = 'en';
  }
  await firstValueFrom(translate.use('en'));
};
