import { RegenerateApiKeyInputDto } from './regenerate-api-key.dtos';

export interface RegenerateApiKeyInputPort {
  execute(dto: RegenerateApiKeyInputDto): void;
}
