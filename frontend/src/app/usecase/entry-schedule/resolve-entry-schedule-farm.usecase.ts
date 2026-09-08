import { Inject, Injectable } from '@angular/core';
import { catchError, of, timeout } from 'rxjs';
import { Farm } from '../../domain/farms/farm';
import { ResolveEntryScheduleFarmInputDto } from './resolve-entry-schedule-farm.dtos';
import { ResolveEntryScheduleFarmInputPort } from './resolve-entry-schedule-farm.input-port';
import {
  RESOLVE_ENTRY_SCHEDULE_FARM_OUTPUT_PORT,
  ResolveEntryScheduleFarmOutputPort
} from './resolve-entry-schedule-farm.output-port';
import { ENTRY_SCHEDULE_GATEWAY, EntryScheduleGateway } from './entry-schedule-gateway';

/** entry_schedule crops API は参照作物ごとに最適化するため CI でも数十秒かかる */
const ENTRY_SCHEDULE_FARM_RESOLVE_HTTP_TIMEOUT_MS = 60_000;

@Injectable()
export class ResolveEntryScheduleFarmUseCase implements ResolveEntryScheduleFarmInputPort {
  constructor(
    @Inject(RESOLVE_ENTRY_SCHEDULE_FARM_OUTPUT_PORT)
    private readonly outputPort: ResolveEntryScheduleFarmOutputPort,
    @Inject(ENTRY_SCHEDULE_GATEWAY) private readonly gateway: EntryScheduleGateway
  ) {}

  execute(dto: ResolveEntryScheduleFarmInputDto): void {
    this.gateway
      .getEntryScheduleFarms(dto.region)
      .pipe(
        timeout(ENTRY_SCHEDULE_FARM_RESOLVE_HTTP_TIMEOUT_MS),
        catchError(() => of([] as Farm[]))
      )
      .subscribe({
        next: (rows) => {
          const farm = rows.find((row) => row.id === dto.farmId);
          if (!farm) {
            this.outputPort.onInvalidFarm();
            return;
          }
          this.outputPort.presentFarm({ farm });
        }
      });
  }
}
