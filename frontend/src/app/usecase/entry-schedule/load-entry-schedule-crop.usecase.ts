import { Inject, Injectable } from '@angular/core';
import { LoadEntryScheduleCropInputDto } from './load-entry-schedule-crop.dtos';
import { LoadEntryScheduleCropInputPort } from './load-entry-schedule-crop.input-port';
import {
  LOAD_ENTRY_SCHEDULE_CROP_OUTPUT_PORT,
  LoadEntryScheduleCropOutputPort
} from './load-entry-schedule-crop.output-port';
import { ENTRY_SCHEDULE_GATEWAY, EntryScheduleGateway } from './entry-schedule-gateway';

@Injectable()
export class LoadEntryScheduleCropUseCase implements LoadEntryScheduleCropInputPort {
  constructor(
    @Inject(LOAD_ENTRY_SCHEDULE_CROP_OUTPUT_PORT)
    private readonly outputPort: LoadEntryScheduleCropOutputPort,
    @Inject(ENTRY_SCHEDULE_GATEWAY) private readonly gateway: EntryScheduleGateway
  ) {}

  execute(dto: LoadEntryScheduleCropInputDto): void {
    this.gateway.getEntryScheduleCrop(dto.farmId, dto.cropId).subscribe({
      next: (data) => {
        this.outputPort.present({ data });
      },
      error: () => {
        this.outputPort.onError({ message: 'entrySchedule.error' });
      }
    });
  }
}
