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
} catch (e) {
  // If injection fails here, some test environments may reconfigure TestBed later.
  // Tests that bootstrap their own TestBed will still be able to import TranslateModule.
  // Swallow the error to avoid breaking the global test setup.
  // console.warn('TranslateService not available at global setup:', e);
}
