import { Inject, Injectable } from '@angular/core';
import { RegenerateApiKeyInputDto } from './regenerate-api-key.dtos';
import { RegenerateApiKeyInputPort } from './regenerate-api-key.input-port';
import {
  RegenerateApiKeyOutputPort,
  REGENERATE_API_KEY_OUTPUT_PORT
} from './regenerate-api-key.output-port';
import { API_KEY_GATEWAY, ApiKeyGateway } from './api-key-gateway';

@Injectable()
export class RegenerateApiKeyUseCase implements RegenerateApiKeyInputPort {
  constructor(
    @Inject(REGENERATE_API_KEY_OUTPUT_PORT)
    private readonly outputPort: RegenerateApiKeyOutputPort,
    @Inject(API_KEY_GATEWAY) private readonly apiKeyGateway: ApiKeyGateway
  ) {}

  execute(dto: RegenerateApiKeyInputDto): void {
    this.apiKeyGateway.regenerateKey().subscribe({
      next: (response) => {
        this.outputPort.onSuccess(response);
        dto.onSuccess?.(response);
      },
      error: (err: Error & { error?: { errors?: string[] } }) =>
        this.outputPort.onError({
          message:
            err.error?.errors?.join(', ') ?? err?.message ?? 'Unknown error'
        })
    });
  }
}
