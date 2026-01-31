import { of } from 'rxjs';
import { CreatePrivatePlanUseCase } from './create-private-plan.usecase';
import { CreatePrivatePlanOutputPort } from './create-private-plan.output-port';
import { PrivatePlanCreateGateway } from './private-plan-create-gateway';
import { CreatePrivatePlanInputDto, CreatePrivatePlanResponseDto } from './create-private-plan.dtos';

describe('CreatePrivatePlanUseCase', () => {
  it('calls outputPort.present with response from gateway', () => {
    const inputDto: CreatePrivatePlanInputDto = {
      farmId: 1,
      planName: 'Test Plan',
      cropIds: [1, 2]
    };

    const response: CreatePrivatePlanResponseDto = { id: 123 };

    const gateway: PrivatePlanCreateGateway = {
      fetchFarms: () => of([]),
      fetchFarm: () => of({} as any),
      fetchCrops: () => of([]),
      createPlan: () => of(response)
    };

    let receivedDto: CreatePrivatePlanResponseDto | null = null;
    const outputPort: CreatePrivatePlanOutputPort = {
      present: (dto) => {
        receivedDto = dto;
      },
      onError: () => {}
    };

    const useCase = new CreatePrivatePlanUseCase(outputPort, gateway);
    useCase.execute(inputDto);

    expect(receivedDto).not.toBeNull();
    expect(receivedDto!.id).toEqual(123);
  });
});