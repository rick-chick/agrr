import { Inject, Injectable } from '@angular/core';
import { LoadApiKeyInputDto } from './load-api-key.dtos';
import { LoadApiKeyInputPort } from './load-api-key.input-port';
import {
  LoadApiKeyOutputPort,
  LOAD_API_KEY_OUTPUT_PORT
} from './load-api-key.output-port';
import { API_KEY_GATEWAY, ApiKeyGateway } from './api-key-gateway';

@Injectable()
export class LoadApiKeyUseCase implements LoadApiKeyInputPort {
  constructor(
    @Inject(LOAD_API_KEY_OUTPUT_PORT)
    private readonly outputPort: LoadApiKeyOutputPort,
    @Inject(API_KEY_GATEWAY) private readonly apiKeyGateway: ApiKeyGateway
  ) {}

  execute(_dto: LoadApiKeyInputDto): void {
    this.apiKeyGateway.getCurrentKey().subscribe({
      next: (apiKey) => this.outputPort.present({ apiKey }),
      error: (err: Error) =>
        this.outputPort.onError({ message: err?.message ?? 'Unknown error' })
    });
  }
}
