import {
  ApplicationConfig,
  ErrorHandler,
  importProvidersFrom,
  inject,
  provideAppInitializer
} from '@angular/core';
import { provideClientHydration } from '@angular/platform-browser';
import { HttpClient, provideHttpClient } from '@angular/common/http';
import { provideRouter } from '@angular/router';
import {
  TranslateLoader,
  TranslateModule,
  provideTranslateParser
} from '@ngx-translate/core';
import { AgrrTranslateParser } from './core/i18n/agrr-translate.parser';

import { routes } from './app.routes';
import { appRouterFeatures } from './app-router-features';
import { createTranslateLoader } from './core/i18n/translate-loader';
import { provideInitialI18nBootstrap } from './core/i18n/initial-i18n-bootstrap';
import { ENTRY_SCHEDULE_GATEWAY } from './usecase/entry-schedule/entry-schedule-gateway';
import { EntryScheduleApiGateway } from './adapters/entry-schedule/entry-schedule-api.gateway';
import { LearnProposalApplicationProgressSyncService } from './services/learn-proposal-application-progress-sync.service';
import { LearnOrchestrationProgressSyncService } from './services/learn-orchestration-progress-sync.service';
import { LearnHandoffSyncService } from './services/learn-handoff-sync.service';
import { AgrrGlobalErrorHandler } from './core/errors/global-error.handler';

export const appConfig: ApplicationConfig = {
  providers: [
    { provide: ErrorHandler, useClass: AgrrGlobalErrorHandler },
    provideClientHydration(),
    provideHttpClient(),
    { provide: ENTRY_SCHEDULE_GATEWAY, useExisting: EntryScheduleApiGateway },
    provideRouter(routes, ...appRouterFeatures),
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
    provideAppInitializer(provideInitialI18nBootstrap()),
    provideAppInitializer(() => {
      inject(LearnProposalApplicationProgressSyncService);
      inject(LearnOrchestrationProgressSyncService);
      inject(LearnHandoffSyncService);
    })
  ]
};
