import { Injectable } from '@angular/core';
import { HomeDemoSectionView } from '../../components/home/home-demo-section.view';
import {
  SyncLandingDemoPlanErrorDto,
  SyncLandingDemoPlanLoadedDto
} from '../../usecase/plans/sync-landing-demo-plan.dtos';
import { SyncLandingDemoPlanOutputPort } from '../../usecase/plans/sync-landing-demo-plan.output-port';

@Injectable()
export class HomeDemoSectionPresenter implements SyncLandingDemoPlanOutputPort {
  private view: HomeDemoSectionView | null = null;

  setView(view: HomeDemoSectionView): void {
    this.view = view;
  }

  onDemoPlanLoaded(dto: SyncLandingDemoPlanLoadedDto): void {
    if (!this.view) {
      throw new Error('HomeDemoSectionPresenter: view not set');
    }
    this.view.applyDemoPlanData(dto.data);
  }

  onLoadError(_dto: SyncLandingDemoPlanErrorDto): void {
    // Landing demo sync is in-memory; errors are unexpected and need no view state.
  }
}
