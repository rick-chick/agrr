import { LoadApiKeyInputDto } from './load-api-key.dtos';

export interface LoadApiKeyInputPort {
  execute(dto: LoadApiKeyInputDto): void;
}
