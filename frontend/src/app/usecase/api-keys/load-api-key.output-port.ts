import { InjectionToken } from '@angular/core';
import { LoadApiKeyDataDto } from './load-api-key.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface LoadApiKeyOutputPort {
  present(dto: LoadApiKeyDataDto): void;
  onError(dto: ErrorDto): void;
}

export const LOAD_API_KEY_OUTPUT_PORT = new InjectionToken<LoadApiKeyOutputPort>(
  'LOAD_API_KEY_OUTPUT_PORT'
);
