import { ApplicationConfig, importProvidersFrom } from '@angular/core';
import { HttpClient, provideHttpClient } from '@angular/common/http';
import { provideRouter } from '@angular/router';
import {
  TranslateLoader,
  TranslateModule,
  provideTranslateParser
} from '@ngx-translate/core';
import { AgrrTranslateParser } from './core/i18n/agrr-translate.parser';
import 'chartjs-adapter-date-fns';

import { routes } from './app.routes';
import { createTranslateLoader } from './core/i18n/translate-loader';
import { ENTRY_SCHEDULE_GATEWAY } from './usecase/entry-schedule/entry-schedule-gateway';
import { EntryScheduleApiGateway } from './adapters/entry-schedule/entry-schedule-api.gateway';

export const appConfig: ApplicationConfig = {
  providers: [
    provideHttpClient(),
    { provide: ENTRY_SCHEDULE_GATEWAY, useExisting: EntryScheduleApiGateway },
    provideRouter(routes),
    importProvidersFrom(
      TranslateModule.forRoot({
        loader: {
          provide: TranslateLoader,
          useFactory: createTranslateLoader,
          deps: [HttpClient]
        },
        parser: provideTranslateParser(AgrrTranslateParser)
      })
    )
  ]
};
