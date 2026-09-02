import { TranslateService } from '@ngx-translate/core';
import { Farm } from '../../domain/farms/farm';
import { localizePublicPlanReferenceFarmName } from '../../core/public-plan-reference-farm-name';

export function displayEntryScheduleFarmName(
  farm: Pick<Farm, 'name' | 'latitude' | 'longitude' | 'region'>,
  translate: TranslateService
): string {
  return localizePublicPlanReferenceFarmName(farm, (key) => translate.instant(key));
}
