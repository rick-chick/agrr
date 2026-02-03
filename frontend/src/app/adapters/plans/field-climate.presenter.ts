import { Injectable } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { FieldCultivationClimateData } from '../../domain/plans/field-cultivation-climate-data';
import {
  FieldClimateView,
  FieldClimateViewState
} from '../../components/plans/field-climate.view';
import { LoadFieldClimateOutputPort } from '../../usecase/plans/field-climate/load-field-climate.output-port';

@Injectable()
export class FieldClimatePresenter implements LoadFieldClimateOutputPort {
  private view: FieldClimateView | null = null;

  setView(view: FieldClimateView): void {
    this.view = view;
  }

  present(dto: FieldCultivationClimateData): void {
    this.ensureView().control = this.createViewState(dto, null);
  }

  onError(dto: ErrorDto): void {
    this.ensureView().control = this.createViewState(null, dto.message);
  }

  private createViewState(
    data: FieldCultivationClimateData | null,
    error: string | null
  ): FieldClimateViewState {
    return {
      loading: false,
      error,
      data
    };
  }

  private ensureView(): FieldClimateView {
    if (!this.view) {
      throw new Error('FieldClimatePresenter: view not set');
    }

    return this.view;
  }
}
