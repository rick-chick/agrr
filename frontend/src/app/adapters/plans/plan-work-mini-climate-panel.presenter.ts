import { Injectable } from '@angular/core';
import { PreviewWorkRowMiniClimateStateDto } from '../../usecase/plans/preview-work-row-mini-climate/preview-work-row-mini-climate.dtos';
import { PreviewWorkRowMiniClimateOutputPort } from '../../usecase/plans/preview-work-row-mini-climate/preview-work-row-mini-climate.output-port';

@Injectable()
export class PlanWorkMiniClimatePanelPresenter implements PreviewWorkRowMiniClimateOutputPort {
  private onUpdate: ((state: PreviewWorkRowMiniClimateStateDto) => void) | null = null;

  setOnUpdate(handler: (state: PreviewWorkRowMiniClimateStateDto) => void): void {
    this.onUpdate = handler;
  }

  presentMiniClimate(state: PreviewWorkRowMiniClimateStateDto): void {
    this.onUpdate?.(state);
  }
}
