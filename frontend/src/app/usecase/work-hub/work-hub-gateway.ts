import { InjectionToken } from '@angular/core';
import { Observable } from 'rxjs';
import { WorkHubListedFarm } from '../../domain/work-hub/work-hub-farm-row';

export interface WorkHubGateway {
  listHubFarms(): Observable<WorkHubListedFarm[]>;
}

export const WORK_HUB_GATEWAY = new InjectionToken<WorkHubGateway>('WORK_HUB_GATEWAY');
