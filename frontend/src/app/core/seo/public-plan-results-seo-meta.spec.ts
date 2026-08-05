import { describe, it, expect } from 'vitest';
import type { CultivationPlanData } from '../../domain/plans/cultivation-plan-data';
import {
  buildPublicPlanResultsShareUrl,
  extractPublicPlanResultsSeoLabels
} from './public-plan-results-seo-meta';

function samplePlan(overrides: Partial<CultivationPlanData['data']> = {}): CultivationPlanData {
  return {
    success: true,
    data: {
      id: 42,
      plan_year: 2026,
      plan_name: '',
      status: 'completed',
      total_area: 1000,
      planning_start_date: '2026-01-01',
      planning_end_date: '2026-12-31',
      fields: [],
      crops: [
        { id: 1, name: 'トマト', area_per_unit: 1, revenue_per_area: 10 },
        { id: 2, name: 'キュウリ', area_per_unit: 1, revenue_per_area: 8 }
      ],
      cultivations: [],
      ...overrides
    },
    total_profit: 0,
    total_revenue: 0,
    total_cost: 0
  };
}

describe('public-plan-results-seo-meta', () => {
  it('buildPublicPlanResultsShareUrl includes planId query', () => {
    expect(buildPublicPlanResultsShareUrl('https://agrr.net', 7)).toBe(
      'https://agrr.net/public-plans/results?planId=7'
    );
    expect(buildPublicPlanResultsShareUrl('', 7)).toBe('');
  });

  it('extractPublicPlanResultsSeoLabels uses plan_name when present', () => {
    const labels = extractPublicPlanResultsSeoLabels(
      samplePlan({ plan_name: '関東（トマト）' })
    );
    expect(labels.planLabel).toBe('関東（トマト）');
    expect(labels.cropLabels).toBe('トマト, キュウリ');
    expect(labels.planYear).toBe(2026);
    expect(labels.totalArea).toBe(1000);
  });

  it('extractPublicPlanResultsSeoLabels falls back to crop names when plan_name empty', () => {
    const labels = extractPublicPlanResultsSeoLabels(samplePlan({ plan_name: '' }));
    expect(labels.planLabel).toBe('トマト, キュウリ');
  });

  it('extractPublicPlanResultsSeoLabels falls back to plan id when no crops', () => {
    const labels = extractPublicPlanResultsSeoLabels(
      samplePlan({ plan_name: '', crops: [], id: 99 })
    );
    expect(labels.planLabel).toBe('Plan #99');
  });
});
