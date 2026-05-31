import { Injectable, inject } from '@angular/core';
import { TranslateService } from '@ngx-translate/core';
import { PublicPlanOptimizingView } from '../../components/public-plans/public-plan-optimizing.view';
import { SubscribePublicPlanOptimizationOutputPort } from '../../usecase/public-plans/subscribe-public-plan-optimization.output-port';
import { PublicPlanOptimizationMessageDto } from '../../usecase/public-plans/subscribe-public-plan-optimization.dtos';

@Injectable()
export class PublicPlanOptimizingPresenter
  implements SubscribePublicPlanOptimizationOutputPort
{
  private view: PublicPlanOptimizingView | null = null;

  private readonly translate = inject(TranslateService);

  setView(view: PublicPlanOptimizingView): void {
    this.view = view;
  }

  /** Rust PassthroughTranslator may put i18n keys in phase_message; always resolve for display. */
  private resolvePhaseMessage(
    dto: PublicPlanOptimizationMessageDto,
    prevMessage: string,
    status: string
  ): string {
    const key =
      dto.message_key ??
      (dto.phase_message?.startsWith('models.') ? dto.phase_message : undefined);
    if (key) {
      const translated = this.translate.instant(key);
      if (translated !== key) {
        return translated;
      }
    }
    if (status === 'completed') {
      return this.translate.instant('models.cultivation_plan.phases.completed');
    }
    return dto.phase_message ?? prevMessage;
  }

  present(dto: PublicPlanOptimizationMessageDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    const prev = this.view.control;
    console.debug('[PublicPlanOptimizingPresenter] present', {
      dto,
      prevViewState: prev
    });
    const nextStatus = dto.status ?? prev.status;
    const nextPhaseMessage = this.resolvePhaseMessage(dto, prev.phaseMessage, nextStatus);
    this.view.control = {
      status: nextStatus,
      progress: typeof dto.progress === 'number' ? dto.progress : prev.progress,
      phaseMessage: nextPhaseMessage
    };
    if (nextStatus === 'completed') {
      this.view.onOptimizationCompleted?.();
    }
  }
}
