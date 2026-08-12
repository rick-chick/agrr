import { Injectable } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { PlanFieldClimateView, PlanFieldClimateViewState } from '../../components/plans/plan-field-climate.view';
import { FieldClimatePresentationDto } from '../../usecase/plans/field-climate/load-field-climate.dtos';
import { LoadFieldClimateOutputPort } from '../../usecase/plans/field-climate/load-field-climate.output-port';

@Injectable()
export class PlanFieldClimatePresenter implements LoadFieldClimateOutputPort {
  private view: PlanFieldClimateView | null = null;

  setView(view: PlanFieldClimateView): void {
    this.view = view;
  }

  present(dto: FieldClimatePresentationDto): void {
    if (!this.view) throw new Error('PlanFieldClimatePresenter: view not set');
    this.view.control = this.createViewState(dto, null);
  }

  onError(dto: ErrorDto): void {
    if (!this.view) throw new Error('PlanFieldClimatePresenter: view not set');
    this.view.control = this.createViewState(null, dto.message);
  }

  private createViewState(
    dto: FieldClimatePresentationDto | null,
    error: string | null
  ): PlanFieldClimateViewState {
    return {
      loading: false,
      error,
      climateData: dto?.climateData ?? null,
      workDayMarkers: dto?.workDayMarkers ?? [],
      latestImplementation: dto?.latestImplementation ?? null
    };
  }
}
