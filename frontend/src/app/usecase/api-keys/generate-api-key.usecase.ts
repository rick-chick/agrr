import { Inject, Injectable } from '@angular/core';
import { GenerateApiKeyInputDto } from './generate-api-key.dtos';
import { GenerateApiKeyInputPort } from './generate-api-key.input-port';
import {
  GenerateApiKeyOutputPort,
  GENERATE_API_KEY_OUTPUT_PORT
} from './generate-api-key.output-port';
import { API_KEY_GATEWAY, ApiKeyGateway } from './api-key-gateway';

@Injectable()
export class GenerateApiKeyUseCase implements GenerateApiKeyInputPort {
  constructor(
    @Inject(GENERATE_API_KEY_OUTPUT_PORT)
    private readonly outputPort: GenerateApiKeyOutputPort,
    @Inject(API_KEY_GATEWAY) private readonly apiKeyGateway: ApiKeyGateway
  ) {}

  execute(dto: GenerateApiKeyInputDto): void {
    this.apiKeyGateway.generateKey().subscribe({
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
