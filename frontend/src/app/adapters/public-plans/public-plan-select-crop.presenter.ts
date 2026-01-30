import { Injectable } from '@angular/core';
import { PublicPlanSelectCropView } from '../../components/public-plans/public-plan-select-crop.view';
import { LoadPublicPlanCropsOutputPort } from '../../usecase/public-plans/load-public-plan-crops.output-port';
import { CreatePublicPlanOutputPort } from '../../usecase/public-plans/create-public-plan.output-port';
import { PublicPlanCropsDataDto } from '../../usecase/public-plans/load-public-plan-crops.dtos';
import { CreatePublicPlanResponse } from '../../usecase/public-plans/public-plan-gateway';
import { ErrorDto } from '../../domain/shared/error.dto';

@Injectable()
export class PublicPlanSelectCropPresenter
  implements LoadPublicPlanCropsOutputPort, CreatePublicPlanOutputPort
{
  private view: PublicPlanSelectCropView | null = null;

  setView(view: PublicPlanSelectCropView): void {
    this.view = view;
  }

  present(dto: PublicPlanCropsDataDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      loading: false,
      error: null,
      crops: dto.crops
    };
  }

  onError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      loading: false,
      saving: false,
      error: dto.message,
      crops: this.view.control.loading ? [] : this.view.control.crops
    };
  }

  onSuccess(_dto: CreatePublicPlanResponse): void {
    // Navigation is handled by Component's onSuccess callback in CreatePublicPlanInputDto
  }
}
