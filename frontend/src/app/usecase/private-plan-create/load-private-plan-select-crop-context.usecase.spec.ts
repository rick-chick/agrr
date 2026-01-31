import { of } from 'rxjs';
import { LoadPrivatePlanSelectCropContextUseCase } from './load-private-plan-select-crop-context.usecase';
import { LoadPrivatePlanSelectCropContextOutputPort } from './load-private-plan-select-crop-context.output-port';
import { PrivatePlanCreateGateway } from './private-plan-create-gateway';
import { PrivatePlanSelectCropContextDataDto } from './load-private-plan-select-crop-context.dtos';
import { Farm } from '../../domain/farms/farm';
import { Crop } from '../../domain/crops/crop';

describe('LoadPrivatePlanSelectCropContextUseCase', () => {
  it('calls outputPort.present with farm, totalArea, and crops from gateway', () => {
    const farm: Farm = { id: 1, name: 'Farm 1', latitude: 35.0, longitude: 135.0, region: 'Kyoto' };
    const totalArea = 100;
    const crops: Crop[] = [
      { id: 1, name: 'Rice', variety: 'Koshihikari', is_reference: false, groups: ['cereal'] },
      { id: 2, name: 'Wheat', variety: 'Norin', is_reference: false, groups: ['cereal'] }
    ];

    const gateway: PrivatePlanCreateGateway = {
      fetchFarms: () => of([]),
      fetchFarm: () => of({ farm, totalArea }),
      fetchCrops: () => of(crops),
      createPlan: () => of({} as any)
    };

    let receivedDto: PrivatePlanSelectCropContextDataDto | null = null;
    const outputPort: LoadPrivatePlanSelectCropContextOutputPort = {
      present: (dto) => {
        receivedDto = dto;
      },
      onError: () => {}
    };

    const useCase = new LoadPrivatePlanSelectCropContextUseCase(outputPort, gateway);
    useCase.execute({ farmId: 1 });

    expect(receivedDto).not.toBeNull();
    expect(receivedDto!.farm).toEqual(farm);
    expect(receivedDto!.totalArea).toEqual(totalArea);
    expect(receivedDto!.crops).toEqual(crops);
  });
});