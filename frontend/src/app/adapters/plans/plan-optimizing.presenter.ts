import { Injectable } from '@angular/core';
import { PlanOptimizingView } from '../../components/plans/plan-optimizing.view';
import { SubscribePlanOptimizationOutputPort } from '../../usecase/plans/subscribe-plan-optimization.output-port';
import { PlanOptimizationMessageDto } from '../../usecase/plans/subscribe-plan-optimization.dtos';

@Injectable()
export class PlanOptimizingPresenter implements SubscribePlanOptimizationOutputPort {
  private view: PlanOptimizingView | null = null;

  setView(view: PlanOptimizingView): void {
    this.view = view;
  }

  present(dto: PlanOptimizationMessageDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    const prev = this.view.control;
    this.view.control = {
      status: dto.status ?? prev.status,
      progress: typeof dto.progress === 'number' ? dto.progress : prev.progress
    };
  }
}
