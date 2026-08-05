import { ApplicationConfig, importProvidersFrom, provideAppInitializer } from '@angular/core';
import { provideClientHydration } from '@angular/platform-browser';
import { HttpClient, provideHttpClient } from '@angular/common/http';
import { provideRouter, withInMemoryScrolling } from '@angular/router';
import {
  TranslateLoader,
  TranslateModule,
  provideTranslateParser
} from '@ngx-translate/core';
import { AgrrTranslateParser } from './core/i18n/agrr-translate.parser';

import { routes } from './app.routes';
import { createTranslateLoader } from './core/i18n/translate-loader';
import { provideInitialI18nBootstrap } from './core/i18n/initial-i18n-bootstrap';
import { ENTRY_SCHEDULE_GATEWAY } from './usecase/entry-schedule/entry-schedule-gateway';
import { EntryScheduleApiGateway } from './adapters/entry-schedule/entry-schedule-api.gateway';

export const appConfig: ApplicationConfig = {
  providers: [
    provideClientHydration(),
    provideHttpClient(),
    { provide: ENTRY_SCHEDULE_GATEWAY, useExisting: EntryScheduleApiGateway },
    provideRouter(
      routes,
      withInMemoryScrolling({
        scrollPositionRestoration: 'enabled',
        anchorScrolling: 'enabled'
      })
    ),
    importProvidersFrom(
      TranslateModule.forRoot({
        loader: {
          provide: TranslateLoader,
          useFactory: createTranslateLoader,
          deps: [HttpClient]
        },
        parser: provideTranslateParser(AgrrTranslateParser)
      })
    ),
    provideAppInitializer(provideInitialI18nBootstrap())
  ]
};
