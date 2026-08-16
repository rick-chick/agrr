import type { FarmPlanCreateOption } from '../../usecase/private-plan-create/private-plan-create-gateway';
import type { PlanCreateReadiness } from './plan-create-readiness';

export interface OnboardingStepView {
  id: 'farm' | 'fields' | 'crops' | 'weather';
  titleKey: string;
  descriptionKey: string;
  ready: boolean;
  routerLink: string | (string | number)[];
}

export function buildOnboardingSteps(
  farms: FarmPlanCreateOption[],
  readiness: PlanCreateReadiness | null
): OnboardingStepView[] {
  const primaryFarm = farms.find((farm) => farm.hasValidFields) ?? farms[0] ?? null;
  const farmLink = farms.length === 0 ? '/farms/new' : '/farms';
  const farmDetailLink = primaryFarm != null ? ['/farms', primaryFarm.id] : '/farms/new';
  const cropsLink = readiness?.cropSummaries.length === 0 ? '/crops/new' : '/crops';

  return [
    {
      id: 'farm',
      titleKey: 'onboarding.steps.farm.title',
      descriptionKey: 'onboarding.steps.farm.description',
      ready: farms.length > 0,
      routerLink: farmLink
    },
    {
      id: 'fields',
      titleKey: 'onboarding.steps.fields.title',
      descriptionKey: 'onboarding.steps.fields.description',
      ready: readiness?.fieldsReady ?? farms.some((farm) => farm.hasValidFields),
      routerLink: farmDetailLink
    },
    {
      id: 'crops',
      titleKey: 'onboarding.steps.crops.title',
      descriptionKey: 'onboarding.steps.crops.description',
      ready: readiness?.cropsReady ?? false,
      routerLink: cropsLink
    },
    {
      id: 'weather',
      titleKey: 'onboarding.steps.weather.title',
      descriptionKey: 'onboarding.steps.weather.description',
      ready: readiness?.weatherReady ?? false,
      routerLink: farmDetailLink
    }
  ];
}
