import { Injectable, signal } from '@angular/core';
import { LoadNavOverdueBadgePresentDto } from '../../usecase/nav/load-nav-overdue-badge.dtos';
import { LoadNavOverdueBadgeOutputPort } from '../../usecase/nav/load-nav-overdue-badge.output-port';

@Injectable()
export class NavOverdueBadgePresenter implements LoadNavOverdueBadgeOutputPort {
  readonly overdueCount = signal(0);

  present(dto: LoadNavOverdueBadgePresentDto): void {
    this.overdueCount.set(dto.overdueCount);
  }

  reset(): void {
    this.overdueCount.set(0);
  }
}
