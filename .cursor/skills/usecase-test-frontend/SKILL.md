---
name: usecase-test-frontend
description: Tests Angular UseCases with Vitest by asserting observable outcomes via Output Port spy and a Fake gateway. Use when writing or reviewing UseCase tests, or ユースケースの単体テスト.
disable-model-invocation: true
---

# UseCase 単体テスト（Angular）

UseCase のテストは **入力 → Output Port に届いた DTO の値・Fake Gateway に蓄積された最終状態** で振る舞いを表明する。`toHaveBeenCalledWith` を**主アサーション**にしない。質の原則は [`test-quality-core.mdc`](../../rules/test-quality.mdc)。フレームワーク方針は [`TEST_FRAMEWORK.md`](../../references/TEST_FRAMEWORK.md)。

## 配置

```
frontend/src/app/usecase/<feature>/<action>.usecase.spec.ts
```

## 何をテストするか

判断・分岐の網羅は UseCase で完結させる（Presenter / Component では網羅しない）。最低限カバーする観点:

- **成功経路の観測** — Output Port spy に届いた DTO の値、Fake Gateway に登録された最終状態。
- **失敗経路の意味分割** — `validation` / `not_found` / `conflict` / `network` / `auth` などエラー種別ごと。汎用 `Error` 一括の検証にしない。
- **境界・不変条件** — 入力境界、複数 Gateway 連携時の合成順序、冪等性。
- **時刻・乱数依存** — clock を注入し固定値で観測する。

## 部品

```typescript
class OutputPortSpy<S, F> {
  success: S | null = null;
  failure: F | null = null;
  present = (dto: S) => { this.success = dto; };
  onError  = (dto: F) => { this.failure = dto; };
}

class PlanFakeGateway implements PlanGateway {
  constructor(private plan: PlanSummary, private data: CultivationPlanData) {}
  fetchPlan = (id: number) => of({ ...this.plan, id });
  fetchPlanData = (id: number) => of(this.data);
}
```

エラー注入には `throwError` でも `class { fetchX = () => throwError(() => new DomainError({ kind: 'network', message })) }` でもよい。

## テンプレート

```typescript
import { of, throwError } from 'rxjs';
import { LoadPlanDetailUseCase } from './load-plan-detail.usecase';

describe('LoadPlanDetailUseCase', () => {
  it('presents plan and planData when gateway succeeds', () => {
    const plan = { id: 7, name: 'Plan 7', status: 'completed' };
    const planData = { success: true, data: { plan_name: 'Plan 7' } } as CultivationPlanData;
    const gateway = new PlanFakeGateway(plan, planData);
    const spy = new OutputPortSpy<PlanDetailDataDto, ErrorDto>();

    new LoadPlanDetailUseCase(spy, gateway).execute({ planId: 7 });

    expect(spy.failure).toBeNull();
    expect(spy.success?.plan.id).toBe(7);
    expect(spy.success?.planData.data.plan_name).toBe('Plan 7');
  });

  it('presents not_found error when plan does not exist', () => {
    const gateway = {
      fetchPlan: () => throwError(() => ({ kind: 'not_found', message: 'plan 7 not found' })),
      fetchPlanData: () => of({} as CultivationPlanData)
    };
    const spy = new OutputPortSpy<PlanDetailDataDto, ErrorDto>();

    new LoadPlanDetailUseCase(spy, gateway).execute({ planId: 7 });

    expect(spy.success).toBeNull();
    expect(spy.failure?.kind).toBe('not_found');
  });

  it('presents network error when gateway fails to reach api', () => {
    const gateway = {
      fetchPlan: () => throwError(() => ({ kind: 'network', message: 'offline' })),
      fetchPlanData: () => of({} as CultivationPlanData)
    };
    const spy = new OutputPortSpy<PlanDetailDataDto, ErrorDto>();

    new LoadPlanDetailUseCase(spy, gateway).execute({ planId: 7 });

    expect(spy.failure?.kind).toBe('network');
  });
});
```

## 層固有の注意

- **役割割当**: Gateway は Fake（RxJS の `of` / `throwError` で固定）、Output Port は Spy。
- **`execute` への入力は UseCase が定義した Input DTO（型）**。

## 参照

- 質の原則・アンチパターン早見表: [`test-quality-core.mdc`](../../rules/test-quality.mdc)
- 実装スキル: [usecase-frontend](../usecase-frontend/SKILL.md)
- Gateway テスト: [gateway-test-frontend](../gateway-test-frontend/SKILL.md)
- Presenter テスト: [presenter-test-frontend](../presenter-test-frontend/SKILL.md)
- 実行: [test-common](../test-common/SKILL.md)
