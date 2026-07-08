import { CultivationPlanData } from '../../domain/plans/cultivation-plan-data';

export interface HomeDemoSectionView {
  applyDemoPlanData(planData: CultivationPlanData): void;
}
