import { Injectable } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { CropListBlueprintsPanelView } from '../../components/masters/crops/crop-list-blueprints-panel.view';
import { LoadCropForEditOutputPort } from '../../usecase/crops/load-crop-for-edit.output-port';
import { LoadCropForEditDataDto } from '../../usecase/crops/load-crop-for-edit.dtos';
import {
  LoadCropTaskScheduleBlueprintsDataDto,
  LoadCropTaskScheduleBlueprintsOutputPort
} from '../../usecase/crops/crop-task-schedule-blueprint.ports';
import { defaultBlueprintReadiness } from '../../domain/crops/blueprint-generation-readiness';
import { withCropListBlueprintsPanelSummaryState } from './crop-list-blueprints-panel-display-state';

const initialSummaryState = {
  blueprintsLoading: true,
  blueprintCount: 0,
  blueprintReadiness: defaultBlueprintReadiness(),
  blueprintSummary: null
};

@Injectable()
export class CropListBlueprintsPanelPresenter
  implements LoadCropForEditOutputPort, LoadCropTaskScheduleBlueprintsOutputPort
{
  private view: CropListBlueprintsPanelView | null = null;

  setView(view: CropListBlueprintsPanelView): void {
    this.view = view;
  }

  present(dto: LoadCropForEditDataDto): void;
  present(dto: LoadCropTaskScheduleBlueprintsDataDto): void;
  present(dto: LoadCropForEditDataDto | LoadCropTaskScheduleBlueprintsDataDto): void {
    if (!this.view) throw new Error('Presenter: view not set');

    if ('crop' in dto) {
      this.view.control = withCropListBlueprintsPanelSummaryState({
        ...this.view.control,
        loading: false,
        error: null,
        crop: dto.crop
      });
      return;
    }

    if ('blueprints' in dto) {
      this.view.control = withCropListBlueprintsPanelSummaryState(
        {
          ...this.view.control,
          blueprintsLoading: false
        },
        dto.blueprints
      );
    }
  }

  onError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = withCropListBlueprintsPanelSummaryState({
      ...this.view.control,
      loading: false,
      blueprintsLoading: false,
      error: dto.message,
      crop: this.view.control.crop,
      ...initialSummaryState
    });
  }
}
