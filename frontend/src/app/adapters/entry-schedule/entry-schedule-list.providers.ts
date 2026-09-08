import { Provider } from '@angular/core';
import { ApiService } from '../../services/api.service';
import { EntryScheduleApiGateway } from './entry-schedule-api.gateway';
import { EntryScheduleListPresenter } from './entry-schedule-list.presenter';
import { LOAD_ENTRY_SCHEDULE_FARMS_OUTPUT_PORT } from '../../usecase/entry-schedule/load-entry-schedule-farms.output-port';
import { LoadEntryScheduleFarmsUseCase } from '../../usecase/entry-schedule/load-entry-schedule-farms.usecase';
import { ENTRY_SCHEDULE_GATEWAY } from '../../usecase/entry-schedule/entry-schedule-gateway';

export const ENTRY_SCHEDULE_LIST_PROVIDERS: readonly Provider[] = [
  LoadEntryScheduleFarmsUseCase,
  EntryScheduleListPresenter,
  { provide: LOAD_ENTRY_SCHEDULE_FARMS_OUTPUT_PORT, useExisting: EntryScheduleListPresenter },
  { provide: ENTRY_SCHEDULE_GATEWAY, useClass: EntryScheduleApiGateway },
  ApiService
];

export { EntryScheduleListPresenter } from './entry-schedule-list.presenter';
