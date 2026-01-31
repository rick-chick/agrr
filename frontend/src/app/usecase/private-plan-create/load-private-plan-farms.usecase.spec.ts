import { of } from 'rxjs';
import { LoadPrivatePlanFarmsUseCase } from './load-private-plan-farms.usecase';
import { LoadPrivatePlanFarmsOutputPort } from './load-private-plan-farms.output-port';
import { PrivatePlanCreateGateway } from './private-plan-create-gateway';
import { PrivatePlanFarmsDataDto } from './load-private-plan-farms.dtos';
import { Farm } from '../../domain/farms/farm';

describe('LoadPrivatePlanFarmsUseCase', () => {
  it('calls outputPort.present with farms from gateway', () => {
    const farms: Farm[] = [
      { id: 1, name: 'Farm 1', latitude: 35.0, longitude: 135.0, region: 'Kyoto' },
      { id: 2, name: 'Farm 2', latitude: 36.0, longitude: 136.0, region: 'Shiga' }
    ];

    const gateway: PrivatePlanCreateGateway = {
      fetchFarms: () => of(farms),
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
  });
});