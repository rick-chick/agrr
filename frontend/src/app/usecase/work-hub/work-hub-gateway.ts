import { InjectionToken } from '@angular/core';
import { Observable } from 'rxjs';
import { WorkHubFarmRow } from '../../domain/work-hub/work-hub-farm-row';

export interface WorkHubGateway {
  listHubFarms(): Observable<WorkHubFarmRow[]>;
}

export const WORK_HUB_GATEWAY = new InjectionToken<WorkHubGateway>('WORK_HUB_GATEWAY');
