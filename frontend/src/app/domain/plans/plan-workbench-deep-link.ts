export function buildPlanWorkbenchDeepLinkQuery(fieldCultivationId: number): {
  field_cultivation_id: number;
} {
  return { field_cultivation_id: fieldCultivationId };
}

export function resolveDeepLinkFieldCultivationId(
  cultivations: ReadonlyArray<{ id: number }>,
  fieldCultivationId: number | null
): number | null {
  if (fieldCultivationId == null || fieldCultivationId <= 0) {
    return null;
  }
  return cultivations.some((cultivation) => cultivation.id === fieldCultivationId)
    ? fieldCultivationId
    : null;
}
