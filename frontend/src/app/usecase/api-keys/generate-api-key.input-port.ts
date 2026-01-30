import { GenerateApiKeyInputDto } from './generate-api-key.dtos';

export interface GenerateApiKeyInputPort {
  execute(dto: GenerateApiKeyInputDto): void;
}
