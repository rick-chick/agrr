/** i18n paths for landing demo fixtures (see assets/i18n). */
export const LANDING_DEMO_I18N_KEYS = {
  planName: 'home.index.demo.fixture.plan_name',
  farmName: 'home.index.demo.fixture.farm_name',
  fieldA: 'home.index.demo.fixture.field_a',
  fieldB: 'home.index.demo.fixture.field_b',
  fieldC: 'home.index.demo.fixture.field_c',
  cropTomato: 'home.index.demo.fixture.crop_tomato',
  cropCucumber: 'home.index.demo.fixture.crop_cucumber',
  cropEggplant: 'home.index.demo.fixture.crop_eggplant',
  cropPepper: 'home.index.demo.fixture.crop_pepper',
  varietyPepper: 'home.index.demo.fixture.variety_pepper',
  varietyEggplant: 'home.index.demo.fixture.variety_eggplant',
  stageGermination: 'home.index.demo.fixture.stage_germination',
  stageGrowth: 'home.index.demo.fixture.stage_growth',
  stageHarvest: 'home.index.demo.fixture.stage_harvest',
  gddStageGrowing: 'home.index.demo.fixture.gdd_stage_growing',
  gddStagePreHarvest: 'home.index.demo.fixture.gdd_stage_pre_harvest'
} as const;

export type LandingDemoLabels = {
  planName: string;
  farmName: string;
  fieldA: string;
  fieldB: string;
  fieldC: string;
  cropTomato: string;
  cropCucumber: string;
  cropEggplant: string;
  cropPepper: string;
  varietyPepper: string;
  varietyEggplant: string;
  stageGermination: string;
  stageGrowth: string;
  stageHarvest: string;
  gddStageGrowing: string;
  gddStagePreHarvest: string;
};

/** English defaults for unit tests (no TranslateModule). */
export const LANDING_DEMO_LABELS_FIXTURE: LandingDemoLabels = {
  planName: 'Sample crop plan (demo)',
  farmName: 'Sample community garden (demo)',
  fieldA: 'Plot A',
  fieldB: 'Plot B',
  fieldC: 'Plot C',
  cropTomato: 'Tomato',
  cropCucumber: 'Cucumber',
  cropEggplant: 'Eggplant',
  cropPepper: 'Bell pepper',
  varietyPepper: 'Sweet long',
  varietyEggplant: 'Senryo No.2',
  stageGermination: 'Germination',
  stageGrowth: 'Growth',
  stageHarvest: 'Harvest',
  gddStageGrowing: 'Vegetative',
  gddStagePreHarvest: 'Pre-harvest'
};
