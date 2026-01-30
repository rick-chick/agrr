import { InjectionToken } from '@angular/core';
import { ApiKeyResponse } from './api-key-gateway';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface GenerateApiKeyOutputPort {
  onSuccess(dto: ApiKeyResponse): void;
  onError(dto: ErrorDto): void;
}

export const GENERATE_API_KEY_OUTPUT_PORT = new InjectionToken<GenerateApiKeyOutputPort>(
  'GENERATE_API_KEY_OUTPUT_PORT'
);
