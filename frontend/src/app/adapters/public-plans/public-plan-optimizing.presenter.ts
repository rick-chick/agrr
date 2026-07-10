import { Injectable, inject } from '@angular/core';
import { TranslateService } from '@ngx-translate/core';
import { PublicPlanOptimizingView } from '../../components/public-plans/public-plan-optimizing.view';
import { SubscribePublicPlanOptimizationOutputPort } from '../../usecase/public-plans/subscribe-public-plan-optimization.output-port';
import { PublicPlanOptimizationMessageDto } from '../../usecase/public-plans/subscribe-public-plan-optimization.dtos';

const PHASE_FAILED_PREFIX = 'models.cultivation_plan.phase_failed.';
const PHASE_FAILED_DEFAULT_KEY = `${PHASE_FAILED_PREFIX}default`;
const PHASES_COMPLETED_KEY = 'models.cultivation_plan.phases.completed';

@Injectable()
export class PublicPlanOptimizingPresenter
  implements SubscribePublicPlanOptimizationOutputPort
{
  private view: PublicPlanOptimizingView | null = null;

  private readonly translate = inject(TranslateService);

  setView(view: PublicPlanOptimizingView): void {
    this.view = view;
  }

  private translateKey(key: string): string | null {
    const translated = this.translate.instant(key);
    return translated !== key ? translated : null;
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

    if (status === 'failed') {
      return this.resolveFailedPhaseMessage(key, dto.phase_message, prevMessage);
    }

    if (key) {
      const translated = this.translateKey(key);
      if (translated) {
        return translated;
      }
    }
    if (status === 'completed') {
      return (
        this.translateKey(PHASES_COMPLETED_KEY) ??
        (dto.phase_message && !dto.phase_message.startsWith('models.')
          ? dto.phase_message
          : prevMessage)
      );
    }
    return dto.phase_message ?? prevMessage;
  }

  private resolveFailedPhaseMessage(
    key: string | undefined,
    phaseMessage: string | undefined,
    prevMessage: string
  ): string {
    const specificKey = this.resolveSpecificFailureKey(key, phaseMessage);
    if (specificKey) {
      const translated = this.translateKey(specificKey);
      if (translated) {
        return translated;
      }
    }

    if (key?.startsWith('models.cultivation_plan.phases.')) {
      const translated = this.translateKey(PHASE_FAILED_DEFAULT_KEY);
      if (translated) {
        return translated;
      }
    }

    if (phaseMessage && !phaseMessage.startsWith('models.')) {
      return phaseMessage;
    }

    return (
      this.translateKey(PHASE_FAILED_DEFAULT_KEY) ??
      this.translateKey('public_plans.optimizing.error.title') ??
      prevMessage
    );
  }

  private resolveFailureHint(
    key: string | undefined,
    phaseMessage: string | undefined
  ): string {
    const category = this.extractFailureCategory(key, phaseMessage);
    const hintKey = `public_plans.optimizing.error.hints.${category}`;
    return (
      this.translateKey(hintKey) ??
      this.translateKey('public_plans.optimizing.error.hints.default') ??
      ''
    );
  }

  private resolveSpecificFailureKey(
    key: string | undefined,
    phaseMessage: string | undefined
  ): string | undefined {
    if (key?.startsWith(PHASE_FAILED_PREFIX) && key !== PHASE_FAILED_DEFAULT_KEY) {
      return key;
    }
    if (
      phaseMessage?.startsWith(PHASE_FAILED_PREFIX) &&
      phaseMessage !== PHASE_FAILED_DEFAULT_KEY
    ) {
      return phaseMessage;
    }
    return undefined;
  }

  private extractFailureCategory(
    key: string | undefined,
    phaseMessage: string | undefined
  ): string {
    for (const candidate of [key, phaseMessage]) {
      if (!candidate?.startsWith(PHASE_FAILED_PREFIX)) {
        continue;
      }
      const suffix = candidate.slice(PHASE_FAILED_PREFIX.length);
      if (suffix && suffix !== 'default') {
        return suffix;
      }
    }
    return 'default';
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
    const failureHint =
      nextStatus === 'failed'
        ? this.resolveFailureHint(dto.message_key, dto.phase_message)
        : undefined;
    this.view.control = {
      status: nextStatus,
      progress: typeof dto.progress === 'number' ? dto.progress : prev.progress,
      phaseMessage: nextPhaseMessage,
      failureHint
    };
    if (nextStatus === 'completed') {
      this.view.onOptimizationCompleted?.();
    }
  }
}
