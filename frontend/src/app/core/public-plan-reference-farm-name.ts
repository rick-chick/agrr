import { resolveReferenceFarmSlug } from '../domain/public-plans/reference-farm-catalog';

export type PublicPlanReferenceFarmNameTranslate = (key: string) => string;

/**
 * Resolves a reference-farm card label for the active UI locale.
 * Falls back to the API name when no catalog entry exists.
 */
export function localizePublicPlanReferenceFarmName(
  farm: { name: string; latitude?: number; longitude?: number; region?: string | null },
  instant: PublicPlanReferenceFarmNameTranslate
): string {
  if (!Number.isFinite(farm.latitude) || !Number.isFinite(farm.longitude)) {
    return farm.name;
  }
  const slug = resolveReferenceFarmSlug({
    name: farm.name,
    latitude: farm.latitude,
    longitude: farm.longitude,
    region: farm.region
  });
  if (!slug) {
    return farm.name;
  }
  const key = `public_plans.reference_farms.${slug}`;
  const translated = instant(key);
  return translated === key ? farm.name : translated;
}
