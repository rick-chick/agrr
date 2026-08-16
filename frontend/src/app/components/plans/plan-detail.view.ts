import { CultivationPlanData } from '../../domain/plans/cultivation-plan-data';
import { PlanSummary } from '../../domain/plans/plan-summary';
import type { PlanVarianceActionItem } from '../../domain/plans/plan-vs-actual-summary';
import type { WeatherRescheduleProposal } from '../../domain/plans/weather-reschedule-proposal';
import type {
  WeatherRescheduleGanttOverlayBar,
  WeatherRescheduleProposalPreview
} from '../../domain/plans/weather-reschedule-proposal-preview';

export type PlanDetailViewState = {
  loading: boolean;
  error: string | null;
  plan: PlanSummary | null;
  planData: CultivationPlanData | null;
  varianceActionItemsOnGantt: PlanVarianceActionItem[];
  weatherProposalsLoading: boolean;
  weatherProposalsError: string | null;
  weatherProposals: WeatherRescheduleProposal[];
  activeWeatherProposalId: string | null;
  weatherPreviewLoading: boolean;
  weatherPreviewError: string | null;
  weatherPreview: WeatherRescheduleProposalPreview | null;
  weatherOverlayBars: WeatherRescheduleGanttOverlayBar[];
  weatherApplyLoading: boolean;
  weatherApplyError: string | null;
};

export interface PlanDetailView {
  get control(): PlanDetailViewState;
  set control(value: PlanDetailViewState);
}
