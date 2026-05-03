import { InjectionToken } from '@angular/core';

/**
 * 公開プラン作成フローのクライアント側セッション状態のうち、
 * ユースケースが更新する最小契約（sessionStorage 等の実装詳細は_ADAPTER/サービス側）。
 */
export interface PublicPlanSessionPort {
  setPlanId(planId: number): void;
  reset(): void;
}

export const PUBLIC_PLAN_SESSION_PORT = new InjectionToken<PublicPlanSessionPort>(
  'PUBLIC_PLAN_SESSION_PORT'
);
