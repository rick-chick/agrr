import { InjectionToken } from '@angular/core';
import { LoadNavOverdueBadgePresentDto } from './load-nav-overdue-badge.dtos';

export interface LoadNavOverdueBadgeOutputPort {
  present(dto: LoadNavOverdueBadgePresentDto): void;
}

export const LOAD_NAV_OVERDUE_BADGE_OUTPUT_PORT = new InjectionToken<LoadNavOverdueBadgeOutputPort>(
  'LOAD_NAV_OVERDUE_BADGE_OUTPUT_PORT'
);
