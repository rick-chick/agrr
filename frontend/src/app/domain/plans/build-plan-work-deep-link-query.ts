export function resolvePlanWorkHighlightItemId(
  unrecordedRows: ReadonlyArray<{ item: { item_id: number } }>
): number | null {
  const first = unrecordedRows[0];
  return first?.item.item_id ?? null;
}

export function buildPlanWorkDeepLinkQuery(
  highlightItemId: number | null
): Record<string, number> | null {
  if (highlightItemId == null) {
    return null;
  }
  return { highlight_item: highlightItemId };
}
