import { ApiKeyResponse } from './api-key-gateway';

export interface GenerateApiKeyInputDto {
  onSuccess?: (response: ApiKeyResponse) => void;
}
