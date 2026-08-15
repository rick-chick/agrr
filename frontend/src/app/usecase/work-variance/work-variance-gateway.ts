import { InjectionToken } from '@angular/core';
import { Observable } from 'rxjs';
import type { VariancePortfolioRow } from '../../domain/work-variance-portfolio/variance-portfolio-row';

export interface WorkVarianceGateway {
  listVariancePortfolio(): Observable<VariancePortfolioRow[]>;
}

export const WORK_VARIANCE_GATEWAY = new InjectionToken<WorkVarianceGateway>('WORK_VARIANCE_GATEWAY');
