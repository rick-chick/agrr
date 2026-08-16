import { Injectable } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { PlanDetailView } from '../../components/plans/plan-detail.view';
import { buildWeatherRescheduleGanttOverlayBars } from '../../domain/plans/build-weather-reschedule-gantt-overlay-bars';
import { dismissWeatherRescheduleProposal } from '../../domain/plans/weather-reschedule-proposal-session';
import type { WeatherRescheduleProposal } from '../../domain/plans/weather-reschedule-proposal';
import type { WeatherRescheduleGanttOverlayBar } from '../../domain/plans/weather-reschedule-proposal-preview';
import { LoadPlanDetailOutputPort } from '../../usecase/plans/load-plan-detail.output-port';
import { PlanDetailDataDto } from '../../usecase/plans/load-plan-detail.dtos';
import {
  PreviewWeatherRescheduleProposalDataDto,
  PreviewWeatherRescheduleProposalOutputPort
} from '../../usecase/plans/preview-weather-reschedule-proposal.output-port';
import {
  ApplyWeatherRescheduleProposalDataDto,
  ApplyWeatherRescheduleProposalOutputPort
} from '../../usecase/plans/apply-weather-reschedule-proposal.output-port';

const emptyWeatherState = {
  weatherProposals: [] as WeatherRescheduleProposal[],
  activeWeatherProposalId: null as string | null,
  weatherPreviewLoading: false,
  weatherPreviewError: null as string | null,
  weatherPreview: null,
  weatherOverlayBars: [] as WeatherRescheduleGanttOverlayBar[],
  weatherApplyLoading: false,
  weatherApplyError: null as string | null
};

@Injectable()
export class PlanDetailPresenter
  implements
    LoadPlanDetailOutputPort,
    PreviewWeatherRescheduleProposalOutputPort,
    ApplyWeatherRescheduleProposalOutputPort
{
  private view: PlanDetailView | null = null;

  setView(view: PlanDetailView): void {
    this.view = view;
  }

  present(dto: PlanDetailDataDto | PreviewWeatherRescheduleProposalDataDto | ApplyWeatherRescheduleProposalDataDto): void {
    if ('preview' in dto) {
      this.presentPreview(dto);
      return;
    }
    if ('planData' in dto && !('plan' in dto)) {
      this.presentApply(dto);
      return;
    }
    this.presentPlanDetail(dto as PlanDetailDataDto);
  }

  onError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    if (this.view.control.weatherPreviewLoading) {
      this.view.control = {
        ...this.view.control,
        weatherPreviewLoading: false,
        weatherPreviewError: dto.message,
        weatherPreview: null,
        weatherOverlayBars: []
      };
      return;
    }
    if (this.view.control.weatherApplyLoading) {
      this.view.control = {
        ...this.view.control,
        weatherApplyLoading: false,
        weatherApplyError: dto.message
      };
      return;
    }
    this.view.control = {
      loading: false,
      error: dto.message,
      plan: null,
      planData: null,
      varianceActionItemsOnGantt: [],
      ...emptyWeatherState
    };
  }

  private presentPlanDetail(dto: PlanDetailDataDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    const activeId = this.view.control.activeWeatherProposalId;
    this.view.control = {
      loading: false,
      error: null,
      plan: dto.plan,
      planData: dto.planData,
      varianceActionItemsOnGantt: dto.varianceActionItemsOnGantt,
      ...emptyWeatherState,
      weatherProposals: dto.weatherProposals,
      activeWeatherProposalId: activeId
    };
  }

  private presentPreview(dto: PreviewWeatherRescheduleProposalDataDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    const cultivations = this.view.control.planData?.data.cultivations ?? [];
    this.view.control = {
      ...this.view.control,
      weatherPreviewLoading: false,
      weatherPreviewError: null,
      weatherPreview: dto.preview,
      weatherOverlayBars: buildWeatherRescheduleGanttOverlayBars(dto.preview, cultivations)
    };
  }

  private presentApply(dto: ApplyWeatherRescheduleProposalDataDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    const appliedId = this.view.control.activeWeatherProposalId;
    const planId = this.view.control.plan?.id;
    if (appliedId && planId) {
      dismissWeatherRescheduleProposal(planId, appliedId);
    }
    this.view.control = {
      ...this.view.control,
      planData: dto.planData,
      weatherApplyLoading: false,
      weatherApplyError: null,
      activeWeatherProposalId: null,
      weatherPreview: null,
      weatherPreviewError: null,
      weatherOverlayBars: [],
      weatherProposals: appliedId
        ? this.view.control.weatherProposals.filter((proposal) => proposal.id !== appliedId)
        : this.view.control.weatherProposals
    };
  }
}
