import { ApiKeyResponse } from './api-key-gateway';

export interface RegenerateApiKeyInputDto {
  onSuccess?: (response: ApiKeyResponse) => void;
}
