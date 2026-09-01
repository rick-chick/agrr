export type PublicPlanPrivateValueItem = {
  icon: string;
  titleKey: string;
  descriptionKey: string;
};

export type PublicPlanSaveNextStepKey = 'save' | 'task_schedule' | 'work_record';

export type PublicPlanSaveNextStep = {
  stepKey: PublicPlanSaveNextStepKey;
  stepNumber: 1 | 2 | 3;
  titleKey: string;
  descriptionKey: string;
};

export const PUBLIC_PLAN_PRIVATE_VALUE_ITEMS: PublicPlanPrivateValueItem[] = [
  {
    icon: '🌧️',
    titleKey: 'public_plans.results.private_value_preview.weather_reschedule.title',
    descriptionKey: 'public_plans.results.private_value_preview.weather_reschedule.description'
  },
  {
    icon: '🔄',
    titleKey: 'public_plans.results.private_value_preview.learn_loop.title',
    descriptionKey: 'public_plans.results.private_value_preview.learn_loop.description'
  },
  {
    icon: '📊',
    titleKey: 'public_plans.results.private_value_preview.work_gdd_comparison.title',
    descriptionKey: 'public_plans.results.private_value_preview.work_gdd_comparison.description'
  }
];

export const PUBLIC_PLAN_SAVE_NEXT_STEPS: PublicPlanSaveNextStep[] = [
  {
    stepKey: 'save',
    stepNumber: 1,
    titleKey: 'public_plans.results.next_steps.save.title',
    descriptionKey: 'public_plans.results.next_steps.save.description'
  },
  {
    stepKey: 'task_schedule',
    stepNumber: 2,
    titleKey: 'public_plans.results.next_steps.task_schedule.title',
    descriptionKey: 'public_plans.results.next_steps.task_schedule.description'
  },
  {
    stepKey: 'work_record',
    stepNumber: 3,
    titleKey: 'public_plans.results.next_steps.work_record.title',
    descriptionKey: 'public_plans.results.next_steps.work_record.description'
  }
];

export function buildPublicPlanSaveNextStepRoute(
  stepKey: PublicPlanSaveNextStepKey,
  savedPlanId: number | null
): (string | number)[] | null {
  if (!savedPlanId) {
    return null;
  }
  switch (stepKey) {
    case 'task_schedule':
      return ['/plans', savedPlanId, 'task_schedule'];
    case 'work_record':
      return ['/plans', savedPlanId, 'work_records'];
    default:
      return null;
  }
}

export function isPublicPlanSaveStepComplete(
  stepKey: PublicPlanSaveNextStepKey,
  savedPlanId: number | null
): boolean {
  if (stepKey === 'save') {
    return savedPlanId !== null;
  }
  return false;
}

export function isPublicPlanSaveStepCurrent(
  stepKey: PublicPlanSaveNextStepKey,
  savedPlanId: number | null
): boolean {
  if (stepKey === 'save') {
    return savedPlanId === null;
  }
  if (stepKey === 'task_schedule') {
    return savedPlanId !== null;
  }
  return false;
}
