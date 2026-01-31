import { describe, it, expect, beforeEach, vi } from 'vitest';
import { of, throwError } from 'rxjs';
import { LoadPublicPlanFarmsUseCase } from './load-public-plan-farms.usecase';
import { LoadPublicPlanFarmsOutputPort } from './load-public-plan-farms.output-port';
import { PublicPlanGateway } from './public-plan-gateway';

describe('LoadPublicPlanFarmsUseCase', () => {
  let outputPort: LoadPublicPlanFarmsOutputPort;
  let gateway: PublicPlanGateway;
  let useCase: LoadPublicPlanFarmsUseCase;

  beforeEach(() => {
    outputPort = {
      present: vi.fn(),
      onError: vi.fn()
    };
    gateway = {
      getFarms: vi.fn(),
      getFarmSizes: vi.fn(),
      getCrops: vi.fn(),
      createPlan: vi.fn(),
      savePlan: vi.fn()
    };
    useCase = new LoadPublicPlanFarmsUseCase(outputPort, gateway);
  });

  // REDテスト: forkJoinが両方のAPIが成功した場合にpresentが呼ばれる
  it('calls present when both APIs succeed', async () => {
    const farms = [{ id: 1, name: 'Test Farm', region: 'jp', latitude: '35.6762', longitude: '139.6503' }];
    const farmSizes = [{ id: 'home_garden', name: 'Home Garden', area_sqm: 30, description: 'Home garden description' }];

    vi.mocked(gateway.getFarms).mockReturnValue(of(farms));
    vi.mocked(gateway.getFarmSizes).mockReturnValue(of(farmSizes));

    useCase.execute({ region: 'jp' });

    // 非同期処理を待つ
    await new Promise(resolve => setTimeout(resolve, 10));

    expect(outputPort.present).toHaveBeenCalledWith({
      farms,
      farmSizes
    });
    expect(outputPort.onError).not.toHaveBeenCalled();
  });

  // REDテスト: getFarmsがエラーの場合、onErrorが呼ばれる
  it('calls onError when getFarms fails', async () => {
    const error = new Error('Network error');

    vi.mocked(gateway.getFarms).mockReturnValue(throwError(() => error));
    vi.mocked(gateway.getFarmSizes).mockReturnValue(of([]));

    useCase.execute({ region: 'jp' });

    // 非同期処理を待つ
    await new Promise(resolve => setTimeout(resolve, 10));

    expect(outputPort.onError).toHaveBeenCalledWith({
      message: 'Network error'
    });
    expect(outputPort.present).not.toHaveBeenCalled();
  });

  // REDテスト: getFarmSizesがエラーの場合、onErrorが呼ばれる
  it('calls onError when getFarmSizes fails', async () => {
    const error = new Error('Network error');

    vi.mocked(gateway.getFarms).mockReturnValue(of([]));
    vi.mocked(gateway.getFarmSizes).mockReturnValue(throwError(() => error));

    useCase.execute({ region: 'jp' });

    // 非同期処理を待つ
    await new Promise(resolve => setTimeout(resolve, 10));

    expect(outputPort.onError).toHaveBeenCalledWith({
      message: 'Network error'
    });
    expect(outputPort.present).not.toHaveBeenCalled();
  });
});