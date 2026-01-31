import { Injectable, inject } from '@angular/core';
import { LoadPrivatePlanSelectCropContextOutputPort } from '../../usecase/private-plan-create/load-private-plan-select-crop-context.output-port';
import { CreatePrivatePlanOutputPort } from '../../usecase/private-plan-create/create-private-plan.output-port';
import { PlanSelectCropView } from '../../components/plans/plan-select-crop.view';
import { PrivatePlanSelectCropContextDataDto } from '../../usecase/private-plan-create/load-private-plan-select-crop-context.dtos';
import { CreatePrivatePlanResponseDto } from '../../usecase/private-plan-create/create-private-plan.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

@Injectable()
export class PlanSelectCropPresenter implements
  LoadPrivatePlanSelectCropContextOutputPort,
  CreatePrivatePlanOutputPort {

  private view: PlanSelectCropView | null = null;

  setView(view: PlanSelectCropView): void {
    this.view = view;
  }

  present(dto: PrivatePlanSelectCropContextDataDto | CreatePrivatePlanResponseDto): void {
    if ('farm' in dto) {
      // LoadPrivatePlanSelectCropContextOutputPort
      if (this.view) {
        this.view.control = {
          loading: false,
          error: null,
          farm: dto.farm,
          totalArea: dto.totalArea,
          crops: dto.crops,
          creating: false
        };
      }
    } else {
      // CreatePrivatePlanOutputPort
      if (this.view) {
        this.view.onPlanCreated(dto.id);
      }
    }
  }

  onError(dto: ErrorDto): void {
    if (this.view) {
      // Check if we're in creating state to determine which error handler to call
      if (this.view.control.creating) {
        this.view.onPlanCreateError(dto.message);
      } else {
        this.view.control = {
          ...this.view.control,
          loading: false,
          error: dto.message
        };
      }
    }
  }
}