import { Injectable, inject } from '@angular/core';
import { TranslateService } from '@ngx-translate/core';
import { PlanOptimizingView } from '../../components/plans/plan-optimizing.view';
import { SubscribePlanOptimizationOutputPort } from '../../usecase/plans/subscribe-plan-optimization.output-port';
import { PlanOptimizationMessageDto } from '../../usecase/plans/subscribe-plan-optimization.dtos';

@Injectable()
export class PlanOptimizingPresenter implements SubscribePlanOptimizationOutputPort {
  private view: PlanOptimizingView | null = null;

  private readonly translate = inject(TranslateService);

  setView(view: PlanOptimizingView): void {
    this.view = view;
  }

  private translateKey(key: string): string | null {
    const translated = this.translate.instant(key);
    return translated !== key ? translated : null;
  }

  private resolvePhaseMessage(dto: PlanOptimizationMessageDto, prevMessage: string): string {
    const key = dto.message_key;
    if (key) {
      const translated = this.translateKey(key);
      if (translated) {
        return translated;
      }
    }
    return prevMessage;
  }

  present(dto: PlanOptimizationMessageDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    const prev = this.view.control;
    const nextStatus = dto.status ?? prev.status;
    const nextProgress = typeof dto.progress === 'number' ? dto.progress : prev.progress;
    const nextPhaseMessage = this.resolvePhaseMessage(dto, prev.phaseMessage);
    this.view.control = {
      status: nextStatus,
      progress: nextProgress,
      phaseMessage: nextPhaseMessage
    };
    if (nextStatus === 'completed' || nextProgress >= 100) {
      this.view.onOptimizationCompleted?.();
    }
  }
}
