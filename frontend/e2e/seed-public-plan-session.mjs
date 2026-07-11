export const PUBLIC_PLAN_SESSION_STORAGE_KEY = 'agrr_public_plan_state';

/**
 * @param {{ id: number; name: string; region: string; latitude?: number; longitude?: number }} farm
 */
export function buildPublicPlanSessionState(farm) {
  return {
    farm: {
      id: farm.id,
      name: farm.name,
      region: farm.region,
      latitude: farm.latitude ?? 0,
      longitude: farm.longitude ?? 0,
    },
    farmSize: { id: '300', area_sqm: 300, name: '300㎡', description: '' },
    selectedCrops: [],
    planId: null,
    pendingCropSlug: null,
  };
}
