import { of, throwError } from 'rxjs';
import { LoadPrivatePlanFarmsUseCase } from './load-private-plan-farms.usecase';
import { LoadPrivatePlanFarmsOutputPort } from './load-private-plan-farms.output-port';
import { FarmPlanCreateOption, PrivatePlanCreateGateway } from './private-plan-create-gateway';
import { PrivatePlanFarmsDataDto } from './load-private-plan-farms.dtos';

describe('LoadPrivatePlanFarmsUseCase', () => {
  it('calls outputPort.present with farms from gateway', () => {
    const farms: FarmPlanCreateOption[] = [
      { id: 1, name: 'Farm 1', fieldCount: 2, totalArea: 100, hasValidFields: true },
      { id: 2, name: 'Farm 2', fieldCount: 0, totalArea: 0, hasValidFields: false }
    ];

    const gateway: PrivatePlanCreateGateway = {
      fetchFarms: () => of([]),
      fetchFarmsForPlanCreate: () => of({ farms, farmCreateLimitReached: false }),
      fetchFarm: () => of({} as any),
      fetchCrops: () => of([]),
      createPlan: () => of({} as any)
    };

    let receivedDto: PrivatePlanFarmsDataDto | null = null;
    const outputPort: LoadPrivatePlanFarmsOutputPort = {
      present: (dto) => {
        receivedDto = dto;
      },
      onError: () => {}
    };

    const useCase = new LoadPrivatePlanFarmsUseCase(outputPort, gateway);
    useCase.execute();

    expect(receivedDto).not.toBeNull();
    expect(receivedDto!.farms).toEqual(farms);
    expect(receivedDto!.farmCreateLimitReached).toBe(false);
  });

  it('passes farmCreateLimitReached from gateway context', () => {
    const gateway: PrivatePlanCreateGateway = {
      fetchFarms: () => of([]),
      fetchFarmsForPlanCreate: () => of({ farms: [], farmCreateLimitReached: true }),
      fetchFarm: () => of({} as any),
      fetchCrops: () => of([]),
      createPlan: () => of({} as any),
    };

    let receivedDto: PrivatePlanFarmsDataDto | null = null;
    const outputPort: LoadPrivatePlanFarmsOutputPort = {
      present: (dto) => {
        receivedDto = dto;
      },
      onError: () => {},
    };

    const useCase = new LoadPrivatePlanFarmsUseCase(outputPort, gateway);
    useCase.execute();

    expect(receivedDto).toEqual({ farms: [], farmCreateLimitReached: true });
  });

  it('calls outputPort.onError when gateway fetch fails', () => {
    const gateway: PrivatePlanCreateGateway = {
      fetchFarms: () => of([]),
      fetchFarmsForPlanCreate: () => throwError(() => new Error('gateway boom')),
      fetchFarm: () => of({} as any),
      fetchCrops: () => of([]),
      createPlan: () => of({} as any),
    };

    let receivedMessage: string | null = null;
    const outputPort: LoadPrivatePlanFarmsOutputPort = {
      present: () => {},
      onError: (dto) => {
        receivedMessage = dto.message;
      },
    };

    const useCase = new LoadPrivatePlanFarmsUseCase(outputPort, gateway);
    useCase.execute();

    expect(receivedMessage).toBe('gateway boom');
  });
});
