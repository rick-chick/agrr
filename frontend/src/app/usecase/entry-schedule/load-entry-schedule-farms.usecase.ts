import { Inject, Injectable } from '@angular/core';
import { catchError, EMPTY, timeout } from 'rxjs';
import { LoadEntryScheduleFarmsInputDto } from './load-entry-schedule-farms.dtos';
import { LoadEntryScheduleFarmsInputPort } from './load-entry-schedule-farms.input-port';
import {
  LOAD_ENTRY_SCHEDULE_FARMS_OUTPUT_PORT,
  LoadEntryScheduleFarmsOutputPort
} from './load-entry-schedule-farms.output-port';
import { ENTRY_SCHEDULE_GATEWAY, EntryScheduleGateway } from './entry-schedule-gateway';

export const ENTRY_SCHEDULE_FARMS_HTTP_TIMEOUT_MS = 25_000;

@Injectable()
export class LoadEntryScheduleFarmsUseCase implements LoadEntryScheduleFarmsInputPort {
  constructor(
    @Inject(LOAD_ENTRY_SCHEDULE_FARMS_OUTPUT_PORT)
    private readonly outputPort: LoadEntryScheduleFarmsOutputPort,
    @Inject(ENTRY_SCHEDULE_GATEWAY) private readonly gateway: EntryScheduleGateway
  ) {}

  execute(dto: LoadEntryScheduleFarmsInputDto): void {
    this.gateway
      .getEntryScheduleFarms(dto.region)
      .pipe(
        timeout(ENTRY_SCHEDULE_FARMS_HTTP_TIMEOUT_MS),
        catchError((err: unknown) => {
          const name =
            err && typeof err === 'object' && 'name' in err
              ? String((err as { name: string }).name)
              : '';
          if (name === 'TimeoutError') {
            this.outputPort.onError({ message: 'entrySchedule.timeout' });
          } else {
            this.outputPort.onError({ message: 'entrySchedule.error' });
          }
          return EMPTY;
        })
      )
      .subscribe({
        next: (farms) => {
          this.outputPort.present({ farms });
        }
      });
  }
}
