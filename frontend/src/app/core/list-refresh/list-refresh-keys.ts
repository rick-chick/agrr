/** ListRefreshBus のチャンネル ID（マスタ一覧の再読込用）。 */
export const LIST_REFRESH_CHANNEL = {
  crops: 'list-refresh:crops',
  farms: 'list-refresh:farms',
  pests: 'list-refresh:pests',
  pesticides: 'list-refresh:pesticides',
  agriculturalTasks: 'list-refresh:agricultural-tasks',
  interactionRules: 'list-refresh:interaction-rules'
} as const;

export type ListRefreshChannelId = (typeof LIST_REFRESH_CHANNEL)[keyof typeof LIST_REFRESH_CHANNEL];
