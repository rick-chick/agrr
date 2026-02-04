import 'zone.js';
import 'zone.js/testing';
import { getTestBed } from '@angular/core/testing';
import {
  BrowserTestingModule,
  platformBrowserTesting
} from '@angular/platform-browser/testing';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
// Import translations for tests
import jaTranslations from './assets/i18n/ja.json';

getTestBed().initTestEnvironment(
  BrowserTestingModule,
  platformBrowserTesting()
);

// Configure TranslateModule and load Japanese translations for tests so
// components using the translate pipe / TranslateService render expected text.
getTestBed().configureTestingModule({
  imports: [TranslateModule.forRoot()]
});

try {
  // Inject TranslateService from the initialized TestBed and set translations.
  const translate = getTestBed().inject(TranslateService);
  translate.setDefaultLang('ja');
  translate.setTranslation('ja', jaTranslations);
  translate.use('ja');
  // Register the same TranslateService instance as a global provider so that
  // standalone components and tests that create their own TestBed can find it.
  getTestBed().configureTestingModule({
    providers: [{ provide: TranslateService, useValue: translate }]
  });
  // Also set an override provider so that tests which create their own TestBed
  // or standalone component injectors will still resolve TranslateService.
  // overrideProvider affects future TestBed module/component creation.
  try {
    getTestBed().overrideProvider(TranslateService, { useValue: translate });
  } catch (e) {
    // Some environments may not support overrideProvider at this point; ignore.
  }
} catch (e) {
  // If injection fails here, some test environments may reconfigure TestBed later.
  // Tests that bootstrap their own TestBed will still be able to import TranslateModule.
  // Swallow the error to avoid breaking the global test setup.
  // console.warn('TranslateService not available at global setup:', e);
}
