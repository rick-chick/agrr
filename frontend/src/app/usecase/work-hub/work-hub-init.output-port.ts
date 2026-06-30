import { InjectionToken } from '@angular/core';
import { WorkHubInitPresentDto } from './work-hub-init.dtos';

export interface WorkHubInitOutputPort {
  present(dto: WorkHubInitPresentDto): void;
  onError(dto: { message: string }): void;
  beginEnsure(): void;
}

export const WORK_HUB_INIT_OUTPUT_PORT = new InjectionToken<WorkHubInitOutputPort>(
  'WORK_HUB_INIT_OUTPUT_PORT'
);
