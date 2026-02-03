import { LoadFieldClimateInputDto } from './load-field-climate.dtos';

export interface LoadFieldClimateInputPort {
  execute(dto: LoadFieldClimateInputDto): void;
}
