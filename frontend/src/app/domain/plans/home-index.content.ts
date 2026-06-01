import {
  HOME_DEMO_SECTION_I18N_KEYS,
  LANDING_DEMO_I18N_KEYS
} from './landing-demo-i18n.keys';

/** Hero block on `/` (HomeComponent). */
export const HOME_INDEX_HERO_I18N_KEYS = {
  title: 'home.index.hero.title',
  subtitleHtml: 'home.index.hero.subtitle_html',
  ctaScrollDemo: 'home.index.hero.cta_scroll_demo',
  ctaFooterLink: 'home.index.hero.cta_footer_link'
} as const;

/** Features section headings (HomeComponent). */
export const HOME_INDEX_FEATURES_HEADING_I18N_KEYS = {
  title: 'home.index.features.title',
  subtitle: 'home.index.features.subtitle'
} as const;

/** Demo section chrome strings (HomeDemoSectionComponent). */
export const HOME_INDEX_DEMO_UI_I18N_KEYS = {
  hintsAria: 'home.index.demo.hints_aria',
  disclaimer: 'home.index.demo.disclaimer',
  ctaCreate: 'home.index.demo.cta_create'
} as const;

export const HOME_DEMO_HINT_I18N_KEYS = [
  'home.index.demo.hints.drag',
  'home.index.demo.hints.tap',
  'home.index.demo.hints.add'
] as const;

export const HOME_INDEX_FEATURES = [
  {
    icon: '📈',
    titleKey: 'home.index.features.growth_prediction.title',
    descKey: 'home.index.features.growth_prediction.description'
  },
  {
    icon: '🌤️',
    titleKey: 'home.index.features.weather.title',
    descKey: 'home.index.features.weather.description'
  },
  {
    icon: '📊',
    titleKey: 'home.index.features.optimization.title',
    descKey: 'home.index.features.optimization.description'
  }
] as const;

/** All `home.index` keys referenced by home route components; used by locale catalog spec. */
export const HOME_INDEX_CATALOG_KEYS = [
  ...Object.values(HOME_INDEX_HERO_I18N_KEYS),
  ...Object.values(HOME_DEMO_SECTION_I18N_KEYS),
  ...Object.values(HOME_INDEX_DEMO_UI_I18N_KEYS),
  ...HOME_DEMO_HINT_I18N_KEYS,
  ...Object.values(LANDING_DEMO_I18N_KEYS),
  ...Object.values(HOME_INDEX_FEATURES_HEADING_I18N_KEYS),
  ...HOME_INDEX_FEATURES.flatMap((feature) => [feature.titleKey, feature.descKey])
] as const;
