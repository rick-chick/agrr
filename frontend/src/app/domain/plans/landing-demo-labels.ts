import { TranslateService } from '@ngx-translate/core';
import {
  LANDING_DEMO_I18N_KEYS,
  LANDING_DEMO_LABELS_FIXTURE,
  LandingDemoLabels
} from './landing-demo-i18n.keys';

export function buildLandingDemoLabels(
  translate: Pick<TranslateService, 'instant'>
): LandingDemoLabels {
  const t = (key: string) => {
    const value = translate.instant(key);
    return value === key ? '' : value;
  };
  const labels: LandingDemoLabels = {
    planName: t(LANDING_DEMO_I18N_KEYS.planName),
    farmName: t(LANDING_DEMO_I18N_KEYS.farmName),
    fieldA: t(LANDING_DEMO_I18N_KEYS.fieldA),
    fieldB: t(LANDING_DEMO_I18N_KEYS.fieldB),
    fieldC: t(LANDING_DEMO_I18N_KEYS.fieldC),
    cropTomato: t(LANDING_DEMO_I18N_KEYS.cropTomato),
    cropCucumber: t(LANDING_DEMO_I18N_KEYS.cropCucumber),
    cropEggplant: t(LANDING_DEMO_I18N_KEYS.cropEggplant),
    cropPepper: t(LANDING_DEMO_I18N_KEYS.cropPepper),
    varietyPepper: t(LANDING_DEMO_I18N_KEYS.varietyPepper),
    varietyEggplant: t(LANDING_DEMO_I18N_KEYS.varietyEggplant),
    stageGermination: t(LANDING_DEMO_I18N_KEYS.stageGermination),
    stageGrowth: t(LANDING_DEMO_I18N_KEYS.stageGrowth),
    stageHarvest: t(LANDING_DEMO_I18N_KEYS.stageHarvest),
    gddStageGrowing: t(LANDING_DEMO_I18N_KEYS.gddStageGrowing),
    gddStagePreHarvest: t(LANDING_DEMO_I18N_KEYS.gddStagePreHarvest)
  };
  const complete = Object.values(labels).every((v) => v.length > 0);
  return complete ? labels : LANDING_DEMO_LABELS_FIXTURE;
}
