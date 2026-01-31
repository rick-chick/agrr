import { Injectable } from '@angular/core';
import { PublicPlanCreateView } from '../../components/public-plans/public-plan-create.view';
import { LoadPublicPlanFarmsOutputPort } from '../../usecase/public-plans/load-public-plan-farms.output-port';
import { PublicPlanFarmsDataDto } from '../../usecase/public-plans/load-public-plan-farms.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

@Injectable()
export class PublicPlanCreatePresenter implements LoadPublicPlanFarmsOutputPort {
  private view: PublicPlanCreateView | null = null;

  setView(view: PublicPlanCreateView): void {
    this.view = view;
  }

  present(dto: PublicPlanFarmsDataDto): void {
    console.log('🌱 [PublicPlanCreatePresenter] present called with:', dto);
    if (!this.view) throw new Error('Presenter: view not set');
    const newControl = {
      ...this.view.control,
      loading: false,
      error: null,
      farms: dto.farms,
      farmSizes: dto.farmSizes
    };
    console.log('🌱 [PublicPlanCreatePresenter] setting control to:', newControl);
    this.view.control = newControl;
    console.log('🌱 [PublicPlanCreatePresenter] control after setting:', this.view.control);
  }

  onError(dto: ErrorDto): void {
    console.log('🌱 [PublicPlanCreatePresenter] onError called with:', dto);
    if (!this.view) throw new Error('Presenter: view not set');
    const newControl = {
      ...this.view.control,
      loading: false,
      error: dto.message,
      farms: [],
      farmSizes: this.view.control.farmSizes
    };
    console.log('🌱 [PublicPlanCreatePresenter] setting control to:', newControl);
    this.view.control = newControl;
  }
}
