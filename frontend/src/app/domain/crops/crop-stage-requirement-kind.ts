const TEMPERATURE_REQUIREMENT_MARKERS = [
  'base_temperature',
  'optimal_min',
  'optimal_max',
  'max_temperature',
  'low_stress_threshold',
  'high_stress_threshold',
  'frost_threshold',
  'sterility_risk_threshold'
] as const;

export type CropStageRequirementKind = 'temperature' | 'thermal' | 'sunshine' | 'nutrient';

export function cropStageRequirementKind(req: unknown): CropStageRequirementKind | null {
  if (!req || typeof req !== 'object') {
    return null;
  }

  const record = req as Record<string, unknown>;
  if (TEMPERATURE_REQUIREMENT_MARKERS.some((key) => key in record)) {
    return 'temperature';
  }
  if ('required_gdd' in record) {
    return 'thermal';
  }
  if ('minimum_sunshine_hours' in record || 'target_sunshine_hours' in record) {
    return 'sunshine';
  }
  if ('daily_uptake_n' in record || 'daily_uptake_p' in record || 'daily_uptake_k' in record) {
    return 'nutrient';
  }
  return null;
}
