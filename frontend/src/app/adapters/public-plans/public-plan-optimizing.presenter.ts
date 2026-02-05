import { Injectable } from '@angular/core';
import { PublicPlanOptimizingView } from '../../components/public-plans/public-plan-optimizing.view';
import { SubscribePublicPlanOptimizationOutputPort } from '../../usecase/public-plans/subscribe-public-plan-optimization.output-port';
import { PublicPlanOptimizationMessageDto } from '../../usecase/public-plans/subscribe-public-plan-optimization.dtos';

@Injectable()
export class PublicPlanOptimizingPresenter
  implements SubscribePublicPlanOptimizationOutputPort
{
  private view: PublicPlanOptimizingView | null = null;

  setView(view: PublicPlanOptimizingView): void {
    this.view = view;
  }

  present(dto: PublicPlanOptimizationMessageDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    const prev = this.view.control;
    console.debug('[PublicPlanOptimizingPresenter] present', {
      dto,
      prevViewState: prev
    });
    const nextStatus = dto.status ?? prev.status;
    this.view.control = {
      status: nextStatus,
      progress: typeof dto.progress === 'number' ? dto.progress : prev.progress,
      phaseMessage: dto.phase_message ?? prev.phaseMessage
    };
    if (nextStatus === 'completed') {
      this.view.onOptimizationCompleted?.();
    }
  }
}
