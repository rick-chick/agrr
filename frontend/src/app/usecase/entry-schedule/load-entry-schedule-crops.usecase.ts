import { Inject, Injectable } from '@angular/core';
import { catchError, EMPTY, timeout } from 'rxjs';
import { LoadEntryScheduleCropsInputDto } from './load-entry-schedule-crops.dtos';
import { LoadEntryScheduleCropsInputPort } from './load-entry-schedule-crops.input-port';
import {
  LOAD_ENTRY_SCHEDULE_CROPS_OUTPUT_PORT,
  LoadEntryScheduleCropsOutputPort
} from './load-entry-schedule-crops.output-port';
import { ENTRY_SCHEDULE_GATEWAY, EntryScheduleGateway } from './entry-schedule-gateway';

/** entry_schedule crops API は参照作物ごとに最適化するため CI でも数十秒かかる */
export const ENTRY_SCHEDULE_CROPS_HTTP_TIMEOUT_MS = 60_000;

@Injectable()
export class LoadEntryScheduleCropsUseCase implements LoadEntryScheduleCropsInputPort {
  constructor(
    @Inject(LOAD_ENTRY_SCHEDULE_CROPS_OUTPUT_PORT)
    private readonly outputPort: LoadEntryScheduleCropsOutputPort,
    @Inject(ENTRY_SCHEDULE_GATEWAY) private readonly gateway: EntryScheduleGateway
  ) {}

  execute(dto: LoadEntryScheduleCropsInputDto): void {
    this.gateway
      .getEntryScheduleCrops(dto.farmId, {
        limit: dto.limit,
        cursor: dto.append ? dto.cursor : undefined
      })
      .pipe(
        timeout(ENTRY_SCHEDULE_CROPS_HTTP_TIMEOUT_MS),
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
        next: (response) => {
          this.outputPort.present({ response, append: dto.append });
        }
      });
  }
}
