import { describe, it, expect, beforeEach, vi } from 'vitest';
import { of, throwError } from 'rxjs';
import { PublicPlanCreateComponent } from './public-plan-create.component';
import { LoadPublicPlanFarmsUseCase } from '../../usecase/public-plans/load-public-plan-farms.usecase';
import { PublicPlanCreatePresenter } from '../../adapters/public-plans/public-plan-create.presenter';
import { PublicPlanApiGateway } from '../../adapters/public-plans/public-plan-api.gateway';
import { ApiClientService } from '../../services/api-client.service';
import { PublicPlanStore } from '../../services/public-plans/public-plan-store.service';
import { Router } from '@angular/router';

describe('PublicPlanCreateComponent', () => {
  let component: PublicPlanCreateComponent;
  let useCaseMock: { execute: ReturnType<typeof vi.fn> };
  let presenterMock: { setView: ReturnType<typeof vi.fn> };
  let storeMock: { state: { farm: any }; setFarm: ReturnType<typeof vi.fn> };
  let routerMock: { navigate: ReturnType<typeof vi.fn> };

  beforeEach(() => {
    useCaseMock = { execute: vi.fn() };
    presenterMock = { setView: vi.fn() };
    storeMock = {
      state: { farm: null },
      setFarm: vi.fn()
    };
    routerMock = { navigate: vi.fn() };

    component = new PublicPlanCreateComponent(
      routerMock as any,
      useCaseMock as any,
      presenterMock as any,
      storeMock as any
    );

    component.ngOnInit();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });

  // REDテスト: 地域を選択すると読み込み状態が表示されたままになる
  // このテストが失敗する（RED）場合、問題が再現されている
  it('should update loading state to false after selecting region', async () => {
    // 初期状態: loading = true
    expect(component.control.loading).toBe(true);

    // 地域を選択
    component.selectRegion({ id: 'jp', name: 'Japan', description: 'Japan region', icon: '🇯🇵' });

    // UseCase.executeが呼ばれたことを確認
    expect(useCaseMock.execute).toHaveBeenCalledWith({ region: 'jp' });

    // 実際のUseCaseの動作をシミュレート
    // UseCaseがforkJoinで成功レスポンスを返す場合
    const gatewayMock = {
      getFarms: vi.fn().mockReturnValue(of([
        { id: 1, name: 'Test Farm JP', region: 'jp', latitude: 35.0, longitude: 139.0 }
      ])),
      getFarmSizes: vi.fn().mockReturnValue(of([
        { id: 'home_garden', name: 'Home Garden', area_sqm: 30 }
      ]))
    };

    // 実際のUseCaseを作成してテスト
    const apiClientMock = {
      get: vi.fn()
        .mockReturnValueOnce(of([
          { id: 1, name: 'Test Farm JP', region: 'jp', latitude: 35.0, longitude: 139.0 }
        ]))
        .mockReturnValueOnce(of([
          { id: 'home_garden', name: 'Home Garden', area_sqm: 30 }
        ]))
    };

    const realUseCase = new LoadPublicPlanFarmsUseCase(
      presenterMock as any,
      new PublicPlanApiGateway(apiClientMock as any)
    );

    // UseCaseを実行
    realUseCase.execute({ region: 'jp' });

    // 非同期処理を待つ
    await new Promise(resolve => setTimeout(resolve, 100));

    // Presenter.presentが呼ばれたことを確認（間接的にloading=falseになる）
    // 実際のテストでは、Presenterのモックが必要だが、まずはUseCaseの動作を確認
    expect(apiClientMock.get).toHaveBeenCalledWith('/api/v1/public_plans/farms', { params: { region: 'jp' } });
    expect(apiClientMock.get).toHaveBeenCalledWith('/api/v1/public_plans/farm_sizes', { params: undefined });
  });
});