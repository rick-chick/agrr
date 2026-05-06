import { Provider } from '@angular/core';
import { ApiKeyApiGateway } from '../../adapters/api-keys/api-key-api.gateway';
import { ApiKeyPresenter } from '../../adapters/api-keys/api-key.presenter';
import { API_KEY_GATEWAY } from './api-key-gateway';
import { GENERATE_API_KEY_OUTPUT_PORT } from './generate-api-key.output-port';
import { GenerateApiKeyUseCase } from './generate-api-key.usecase';
import { LOAD_API_KEY_OUTPUT_PORT } from './load-api-key.output-port';
import { LoadApiKeyUseCase } from './load-api-key.usecase';
import { REGENERATE_API_KEY_OUTPUT_PORT } from './regenerate-api-key.output-port';
import { RegenerateApiKeyUseCase } from './regenerate-api-key.usecase';

export const API_KEY_PROVIDERS: readonly Provider[] = [
  ApiKeyPresenter,
  LoadApiKeyUseCase,
  GenerateApiKeyUseCase,
  RegenerateApiKeyUseCase,
  { provide: LOAD_API_KEY_OUTPUT_PORT, useExisting: ApiKeyPresenter },
  { provide: GENERATE_API_KEY_OUTPUT_PORT, useExisting: ApiKeyPresenter },
  { provide: REGENERATE_API_KEY_OUTPUT_PORT, useExisting: ApiKeyPresenter },
  { provide: API_KEY_GATEWAY, useClass: ApiKeyApiGateway }
];

export { ApiKeyPresenter } from '../../adapters/api-keys/api-key.presenter';
