import { ApplicationConfig, importProvidersFrom } from '@angular/core';
import { HttpClient, provideHttpClient } from '@angular/common/http';
import { provideRouter } from '@angular/router';
import { HashLocationStrategy, LocationStrategy } from '@angular/common';
import { TranslateLoader, TranslateModule } from '@ngx-translate/core';
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
    { provide: LocationStrategy, useClass: HashLocationStrategy },
    importProvidersFrom(
      TranslateModule.forRoot({
        loader: {
          provide: TranslateLoader,
          useFactory: createTranslateLoader,
          deps: [HttpClient]
        }
      })
    )
  ]
};
