export interface SetupProposalBlueprintPreviewRow {
  track: string;
  stageOrder: number | null;
  label: string;
  highlighted: boolean;
}

function readStageOrder(value: unknown): number | null {
  if (typeof value !== 'object' || value == null) {
    return null;
  }
  const record = value as Record<string, unknown>;
  const raw = record['stage_order'];
  if (typeof raw === 'number' && Number.isInteger(raw)) {
    return raw;
  }
  return null;
}

function blueprintLabel(value: unknown, index: number): string {
  if (typeof value !== 'object' || value == null) {
    return `Blueprint ${index + 1}`;
  }
  const record = value as Record<string, unknown>;
  const stageName = record['stage_name'];
  const taskType = record['task_type'];
  const blueprintId = record['blueprint_id'];
  const parts: string[] = [];
  if (typeof stageName === 'string' && stageName.length > 0) {
    parts.push(stageName);
  }
  if (typeof taskType === 'string' && taskType.length > 0) {
    parts.push(taskType);
  }
  if (typeof blueprintId === 'number') {
    parts.push(`#${blueprintId}`);
  }
  return parts.length > 0 ? parts.join(' · ') : `Blueprint ${index + 1}`;
}

export function buildSetupProposalBlueprintPreviewRows(
  preview: unknown,
  handoffHighlightStageOrder: number | null
): SetupProposalBlueprintPreviewRow[] {
  if (typeof preview !== 'object' || preview == null) {
    return [];
  }
  const blueprints = (preview as Record<string, unknown>)['task_schedule_blueprints'];
  if (!Array.isArray(blueprints)) {
    return [];
  }

  return blueprints.map((entry, index) => {
    const stageOrder = readStageOrder(entry);
    const highlighted =
      handoffHighlightStageOrder != null && stageOrder === handoffHighlightStageOrder;
    return {
      track: `${index}:${stageOrder ?? 'null'}`,
      stageOrder,
      label: blueprintLabel(entry, index),
      highlighted
    };
  });
}
