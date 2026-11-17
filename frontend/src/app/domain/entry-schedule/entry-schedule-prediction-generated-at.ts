/** Display chip for entry-schedule prediction `generated_at` (matches `slice(0, 16)` on ISO strings). */
export function formatEntrySchedulePredictionGeneratedAt(raw: string): string {
  const trimmed = raw.trim();
  if (/^\d+$/.test(trimmed)) {
    const ms = Number(trimmed) * 1000;
    if (Number.isFinite(ms)) {
      const iso = new Date(ms).toISOString();
      if (!Number.isNaN(new Date(ms).getTime())) {
        return iso.slice(0, 16);
      }
    }
  }
  return trimmed.slice(0, 16);
}