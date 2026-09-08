import { Provider } from '@angular/core';
import { ApiService } from '../../services/api.service';
import { EntryScheduleApiGateway } from './entry-schedule-api.gateway';
import { EntryScheduleDetailPresenter } from './entry-schedule-detail.presenter';
import { LOAD_ENTRY_SCHEDULE_CROP_OUTPUT_PORT } from '../../usecase/entry-schedule/load-entry-schedule-crop.output-port';
import { LoadEntryScheduleCropUseCase } from '../../usecase/entry-schedule/load-entry-schedule-crop.usecase';
import { ENTRY_SCHEDULE_GATEWAY } from '../../usecase/entry-schedule/entry-schedule-gateway';

export const ENTRY_SCHEDULE_DETAIL_PROVIDERS: readonly Provider[] = [
  LoadEntryScheduleCropUseCase,
  EntryScheduleDetailPresenter,
  { provide: LOAD_ENTRY_SCHEDULE_CROP_OUTPUT_PORT, useExisting: EntryScheduleDetailPresenter },
  { provide: ENTRY_SCHEDULE_GATEWAY, useClass: EntryScheduleApiGateway },
  ApiService
];

export { EntryScheduleDetailPresenter } from './entry-schedule-detail.presenter';
