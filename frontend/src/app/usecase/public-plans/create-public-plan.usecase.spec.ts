import { throwError, of } from 'rxjs';
import { CreatePublicPlanUseCase } from './create-public-plan.usecase';
import { CreatePublicPlanOutputPort } from './create-public-plan.output-port';
import { PublicPlanGateway } from './public-plan-gateway';
import { CreatePublicPlanInputDto } from './create-public-plan.dtos';

describe('CreatePublicPlanUseCase', () => {
  it('calls outputPort.onSuccess when gateway succeeds', () => {
    const inputDto: CreatePublicPlanInputDto = {
      farmId: 1,
      farmSizeId: 'home_garden',
      cropIds: [1]
    };
    const gateway: PublicPlanGateway = {
      getFarms: () => of([]),
      getFarmSizes: () => of([]),
      getCrops: () => of([]),
      createPlan: () => of({ plan_id: 99 }),
      savePlan: () => of({} as any)
    };
    let receivedPlanId: number | null = null;
    const outputPort: CreatePublicPlanOutputPort = {
      onError: () => {},
      onSuccess: (r) => {
        receivedPlanId = r.plan_id;
      }
    };
    const useCase = new CreatePublicPlanUseCase(outputPort, gateway);
    useCase.execute(inputDto);
    expect(receivedPlanId).toBe(99);
  });

  /**
   * Rails は 422 で単一キー { error: "..." } を返す。
   * そのメッセージが onError に渡ることを断言（RED→GREEN で原因特定用）。
   */
  it('passes single error message from 422 response to onError', () => {
    const railsErrorBody = { error: '作物を1つ以上選択してください。' };
    const gateway: PublicPlanGateway = {
      getFarms: () => of([]),
      getFarmSizes: () => of([]),
      getCrops: () => of([]),
      createPlan: () =>
        throwError(() => ({ status: 422, error: railsErrorBody })),
      savePlan: () => of({} as any)
    };
    let receivedMessage: string | null = null;
    const outputPort: CreatePublicPlanOutputPort = {
      onError: (dto) => {
        receivedMessage = dto.message;
      },
      onSuccess: () => {}
    };
    const useCase = new CreatePublicPlanUseCase(outputPort, gateway);
    useCase.execute({
      farmId: 1,
      farmSizeId: 'home_garden',
      cropIds: []
    });
    expect(receivedMessage).toBe('作物を1つ以上選択してください。');
  });
});
