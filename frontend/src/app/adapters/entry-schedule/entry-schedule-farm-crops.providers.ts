import { Provider } from '@angular/core';
import { ApiService } from '../../services/api.service';
import { EntryScheduleApiGateway } from './entry-schedule-api.gateway';
import { EntryScheduleFarmCropsPresenter } from './entry-schedule-farm-crops.presenter';
import { LOAD_ENTRY_SCHEDULE_CROPS_OUTPUT_PORT } from '../../usecase/entry-schedule/load-entry-schedule-crops.output-port';
import { LoadEntryScheduleCropsUseCase } from '../../usecase/entry-schedule/load-entry-schedule-crops.usecase';
import { RESOLVE_ENTRY_SCHEDULE_FARM_OUTPUT_PORT } from '../../usecase/entry-schedule/resolve-entry-schedule-farm.output-port';
import { ResolveEntryScheduleFarmUseCase } from '../../usecase/entry-schedule/resolve-entry-schedule-farm.usecase';
import { ENTRY_SCHEDULE_GATEWAY } from '../../usecase/entry-schedule/entry-schedule-gateway';

export const ENTRY_SCHEDULE_FARM_CROPS_PROVIDERS: readonly Provider[] = [
  EntryScheduleFarmCropsPresenter,
  LoadEntryScheduleCropsUseCase,
  ResolveEntryScheduleFarmUseCase,
  { provide: LOAD_ENTRY_SCHEDULE_CROPS_OUTPUT_PORT, useExisting: EntryScheduleFarmCropsPresenter },
  { provide: RESOLVE_ENTRY_SCHEDULE_FARM_OUTPUT_PORT, useExisting: EntryScheduleFarmCropsPresenter },
  { provide: ENTRY_SCHEDULE_GATEWAY, useClass: EntryScheduleApiGateway },
  ApiService
];

export { EntryScheduleFarmCropsPresenter } from './entry-schedule-farm-crops.presenter';
