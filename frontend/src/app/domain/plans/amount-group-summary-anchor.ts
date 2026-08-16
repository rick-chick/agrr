function amountGroupSummaryKey(
  stageOrder: number | null,
  category: string,
  taskType: string
): string {
  return `${stageOrder ?? 'none'}-${category}-${taskType}`;
}

export function amountGroupSummaryAnchorId(
  stageOrder: number | null,
  category: string,
  taskType: string
): string {
  return `plan-learn-amount-group-${amountGroupSummaryKey(stageOrder, category, taskType)}`;
}

export function bpAmountProposalAnchorId(
  stageOrder: number | null,
  category: string,
  taskType: string
): string {
  return `plan-learn-bp-amount-proposal-${amountGroupSummaryKey(stageOrder, category, taskType)}`;
}
