export function parseFromPlanId(raw: string | null): number | null {
  if (raw == null) {
    return null;
  }
  const id = Number(raw);
  return id > 0 ? id : null;
}
