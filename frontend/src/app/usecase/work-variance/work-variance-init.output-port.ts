import { WorkVarianceInitPresentDto } from './work-variance-init.dtos';

export interface WorkVarianceInitOutputPort {
  present(dto: WorkVarianceInitPresentDto): void;
  onError(dto: { message: string }): void;
}

export const WORK_VARIANCE_INIT_OUTPUT_PORT = Symbol('WORK_VARIANCE_INIT_OUTPUT_PORT');
