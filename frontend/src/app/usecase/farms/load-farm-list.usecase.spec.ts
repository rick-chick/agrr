import { of } from 'rxjs';
import { LoadFarmListUseCase } from './load-farm-list.usecase';
import { FarmGateway, FARM_GATEWAY } from './farm-gateway';
import { LoadFarmListOutputPort, LOAD_FARM_LIST_OUTPUT_PORT } from './load-farm-list.output-port';
import { FarmListDataDto } from './load-farm-list.dtos';
import { Farm } from '../../domain/farms/farm';

describe('LoadFarmListUseCase', () => {
  it('calls outputPort.present with farms from gateway', () => {
    const farms: Farm[] = [
      {
        id: 1,
        name: 'Farm 1',
        latitude: 35.6895,
        longitude: 139.6917,
        region: 'jp',
        is_reference: false
      },
      {
        id: 2,
        name: 'Reference Farm',
        latitude: 43.0642,
        longitude: 141.3468,
        region: 'jp',
        is_reference: true
      }
    ];

    const gateway: FarmGateway = {
      list: () => of(farms),
      show: () => of({} as Farm),
      listFieldsByFarm: () => of([]),
      create: () => of({} as Farm),
      update: () => of({} as Farm),
      destroy: () => of({} as any),
      createField: () => of({} as any),
      updateField: () => of({} as any),
      destroyField: () => of({} as any)
    };

    let receivedDto: FarmListDataDto | null = null;
    const outputPort: LoadFarmListOutputPort = {
      present: (dto) => {
        receivedDto = dto;
      },
      onError: () => {}
    };

    const useCase = new LoadFarmListUseCase(outputPort, gateway);
    useCase.execute();

    expect(receivedDto).not.toBeNull();
    expect(receivedDto!.farms).toEqual(farms);
  });

});