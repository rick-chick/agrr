import { InjectionToken } from '@angular/core';
import { ApiKeyResponse } from './api-key-gateway';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface RegenerateApiKeyOutputPort {
  onSuccess(dto: ApiKeyResponse): void;
  onError(dto: ErrorDto): void;
}

export const REGENERATE_API_KEY_OUTPUT_PORT = new InjectionToken<RegenerateApiKeyOutputPort>(
  'REGENERATE_API_KEY_OUTPUT_PORT'
);
