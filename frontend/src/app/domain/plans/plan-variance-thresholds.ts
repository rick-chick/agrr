/** Mirrors `plan_variance_threshold_policy::DEFAULT_GDD_THRESHOLD`. */
export const GDD_VARIANCE_THRESHOLD = 10.0;

/** Mirrors `plan_variance_threshold_policy::DEFAULT_DAYS_THRESHOLD`. */
export const DAYS_VARIANCE_THRESHOLD = 3;

/** Mirrors `plan_variance_threshold_policy::DEFAULT_AMOUNT_DELTA_THRESHOLD`. */
export const AMOUNT_VARIANCE_THRESHOLD = 0.5;

/** Mirrors `plan_variance_threshold_policy::FERTILIZER_AMOUNT_DELTA_THRESHOLD`. */
export const FERTILIZER_AMOUNT_DELTA_THRESHOLD = 0.5;

/** Mirrors `plan_variance_threshold_policy::PEST_CONTROL_AMOUNT_DELTA_THRESHOLD`. */
export const PEST_CONTROL_AMOUNT_DELTA_THRESHOLD = 0.2;

export function amountDeltaThresholdForCategory(category: string): number {
  switch (category) {
    case 'fertilizer':
      return FERTILIZER_AMOUNT_DELTA_THRESHOLD;
    case 'pest_control':
      return PEST_CONTROL_AMOUNT_DELTA_THRESHOLD;
    default:
      return AMOUNT_VARIANCE_THRESHOLD;
  }
}
