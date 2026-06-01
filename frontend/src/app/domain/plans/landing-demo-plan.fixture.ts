import { CultivationPlanData } from './cultivation-plan-data';
import { LANDING_DEMO_PLAN_ID } from './cultivation-plan-context-type';
import { LandingDemoLabels, LANDING_DEMO_LABELS_FIXTURE } from './landing-demo-i18n.keys';

/** Initial landing-page demo plan (client-only; not loaded from API). */
export function buildLandingDemoPlanFixture(
  labels: LandingDemoLabels = LANDING_DEMO_LABELS_FIXTURE
): CultivationPlanData {
  return {
    success: true,
    data: {
      id: LANDING_DEMO_PLAN_ID,
      plan_year: 2026,
      plan_name: labels.planName,
      status: 'completed',
      total_area: 90,
      planning_start_date: '2026-01-01',
      planning_end_date: '2026-12-31',
      fields: [
        { id: 101, field_id: 1, name: labels.fieldA, area: 30, daily_fixed_cost: 0 },
        { id: 102, field_id: 2, name: labels.fieldB, area: 30, daily_fixed_cost: 0 },
        { id: 103, field_id: 3, name: labels.fieldC, area: 30, daily_fixed_cost: 0 }
      ],
      crops: [
        { id: 201, name: labels.cropTomato, area_per_unit: 0.5, revenue_per_area: 1200 },
        { id: 202, name: labels.cropCucumber, area_per_unit: 0.4, revenue_per_area: 900 },
        { id: 203, name: labels.cropEggplant, area_per_unit: 0.45, revenue_per_area: 1000 },
        { id: 204, name: labels.cropPepper, area_per_unit: 0.35, revenue_per_area: 800 }
      ],
      available_crops: [
        {
          id: 204,
          name: labels.cropPepper,
          variety: labels.varietyPepper,
          area_per_unit: 0.35
        },
        {
          id: 203,
          name: labels.cropEggplant,
          variety: labels.varietyEggplant,
          area_per_unit: 0.45
        }
      ],
      cultivations: [
        {
          id: 501,
          field_id: 101,
          field_name: labels.fieldA,
          crop_id: 201,
          crop_name: labels.cropTomato,
          area: 12,
          start_date: '2026-04-10',
          completion_date: '2026-08-20',
          cultivation_days: 133,
          estimated_cost: 0,
          revenue: 0,
          profit: 0,
          status: 'completed'
        },
        {
          id: 502,
          field_id: 102,
          field_name: labels.fieldB,
          crop_id: 202,
          crop_name: labels.cropCucumber,
          area: 10,
          start_date: '2026-05-01',
          completion_date: '2026-07-15',
          cultivation_days: 76,
          estimated_cost: 0,
          revenue: 0,
          profit: 0,
          status: 'completed'
        },
        {
          id: 503,
          field_id: 103,
          field_name: labels.fieldC,
          crop_id: 203,
          crop_name: labels.cropEggplant,
          area: 11,
          start_date: '2026-06-01',
          completion_date: '2026-09-30',
          cultivation_days: 122,
          estimated_cost: 0,
          revenue: 0,
          profit: 0,
          status: 'completed'
        }
      ]
    },
    total_profit: 0,
    total_revenue: 0,
    total_cost: 0
  };
}
