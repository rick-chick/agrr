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
      getCrops: vi.fn(),
      createPlan: vi.fn(),
      savePlan: vi.fn()
    };
    useCase = new LoadPublicPlanFarmsUseCase(outputPort, gateway);
  });

  it('calls present when getFarms succeeds', async () => {
    const farms = [{ id: 1, name: 'Test Farm', region: 'jp', latitude: 35.6762, longitude: 139.6503 }];

    vi.mocked(gateway.getFarms).mockReturnValue(of(farms));

    useCase.execute({ region: 'jp' });

    await new Promise((resolve) => setTimeout(resolve, 10));

    expect(outputPort.present).toHaveBeenCalledWith({ farms });
    expect(outputPort.onError).not.toHaveBeenCalled();
  });

  it('calls onError when getFarms fails', async () => {
    const error = new Error('Network error');

    vi.mocked(gateway.getFarms).mockReturnValue(throwError(() => error));

    useCase.execute({ region: 'jp' });

    await new Promise((resolve) => setTimeout(resolve, 10));

    expect(outputPort.onError).toHaveBeenCalledWith({
      message: 'Network error'
    });
    expect(outputPort.present).not.toHaveBeenCalled();
  });
});
