import { Injectable } from '@angular/core';
import { ApiKeyView } from '../../components/settings/api-key/api-key.view';
import { LoadApiKeyOutputPort } from '../../usecase/api-keys/load-api-key.output-port';
import { LoadApiKeyDataDto } from '../../usecase/api-keys/load-api-key.dtos';
import { GenerateApiKeyOutputPort } from '../../usecase/api-keys/generate-api-key.output-port';
import { RegenerateApiKeyOutputPort } from '../../usecase/api-keys/regenerate-api-key.output-port';
import { ApiKeyResponse } from '../../usecase/api-keys/api-key-gateway';
import { ErrorDto } from '../../domain/shared/error.dto';

@Injectable()
export class ApiKeyPresenter
  implements LoadApiKeyOutputPort, GenerateApiKeyOutputPort, RegenerateApiKeyOutputPort
{
  private view: ApiKeyView | null = null;

  setView(view: ApiKeyView): void {
    this.view = view;
  }

  present(dto: LoadApiKeyDataDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      loading: false,
      error: null,
      apiKey: dto.apiKey ?? ''
    };
  }

  onError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      loading: false,
      generating: false,
      error: dto.message
    };
  }

  onSuccess(response: ApiKeyResponse): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      generating: false,
      error: null,
      apiKey: response.api_key
    };
  }
}
