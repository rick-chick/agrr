import { Component, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { TranslateModule } from '@ngx-translate/core';
import { ApiKeyView, ApiKeyViewState } from './api-key.view';
import { LoadApiKeyUseCase } from '../../../usecase/api-keys/load-api-key.usecase';
import { GenerateApiKeyUseCase } from '../../../usecase/api-keys/generate-api-key.usecase';
import { RegenerateApiKeyUseCase } from '../../../usecase/api-keys/regenerate-api-key.usecase';
import { ApiKeyPresenter } from '../../../adapters/api-keys/api-key.presenter';
import { LOAD_API_KEY_OUTPUT_PORT } from '../../../usecase/api-keys/load-api-key.output-port';
import { GENERATE_API_KEY_OUTPUT_PORT } from '../../../usecase/api-keys/generate-api-key.output-port';
import { REGENERATE_API_KEY_OUTPUT_PORT } from '../../../usecase/api-keys/regenerate-api-key.output-port';
import { API_KEY_GATEWAY } from '../../../usecase/api-keys/api-key-gateway';
import { ApiKeyApiGateway } from '../../../adapters/api-keys/api-key-api.gateway';

const initialControl: ApiKeyViewState = {
  loading: true,
  error: null,
  apiKey: '',
  copyButtonLabel: 'コピー',
  generating: false
};

@Component({
  selector: 'app-api-key',
  standalone: true,
  imports: [CommonModule, FormsModule, TranslateModule],
  providers: [
    ApiKeyPresenter,
    LoadApiKeyUseCase,
    GenerateApiKeyUseCase,
    RegenerateApiKeyUseCase,
    { provide: LOAD_API_KEY_OUTPUT_PORT, useExisting: ApiKeyPresenter },
    { provide: GENERATE_API_KEY_OUTPUT_PORT, useExisting: ApiKeyPresenter },
    { provide: REGENERATE_API_KEY_OUTPUT_PORT, useExisting: ApiKeyPresenter },
    { provide: API_KEY_GATEWAY, useClass: ApiKeyApiGateway }
  ],
  template: `
    <div class="page-content-container">
      <div class="page-header">
        <h1>{{ 'api_keys.title' | translate }}</h1>
      </div>

      <div class="info-box">
        <p class="info-box-content">{{ 'api_keys.warning' | translate }}</p>

        @if (control.apiKey) {
          <div class="form-group mb-6">
            <label class="block text-sm font-medium text-gray-700 mb-2">{{ 'api_keys.label' | translate }}</label>
            <div class="flex gap-2">
              <input
                type="text"
                class="flex-1 p-2 border rounded bg-gray-50"
                [value]="control.apiKey"
                readonly
              >
              <button
                type="button"
                class="px-4 py-2 bg-gray-200 rounded hover:bg-gray-300 transition-colors"
                (click)="copyToClipboard()"
              >
                {{ control.copyButtonLabel }}
              </button>
            </div>
          </div>

          <div class="flex gap-4">
            <button
              type="button"
              class="px-6 py-2 bg-yellow-500 text-white rounded hover:bg-yellow-600 transition-colors"
              (click)="regenerate()"
              [disabled]="control.generating"
            >
              {{ 'api_keys.actions.regenerate' | translate }}
            </button>
          </div>
        } @else {
          <div class="bg-blue-50 p-4 rounded mb-6">
            <p class="text-blue-700">{{ 'api_keys.notices.missing' | translate }}</p>
          </div>

          <button
            type="button"
            class="px-6 py-2 bg-green-600 text-white rounded hover:bg-green-700 transition-colors"
            (click)="generate()"
            [disabled]="control.generating"
          >
            {{ 'api_keys.actions.generate' | translate }}
          </button>
        }

        @if (control.error) {
          <p class="text-red-600 mt-2">{{ control.error }}</p>
        }
      </div>

      @if (control.loading) {
        <p class="text-gray-500">{{ 'common.loading' | translate }}</p>
      } @else {
        <div class="info-box mt-8">
          <h2 class="info-box-title">{{ 'api_keys.usage.heading' | translate }}</h2>

          <div class="mb-6">
            <h3 class="font-bold mb-2">{{ 'api_keys.usage.headers.header' | translate }}</h3>
            <pre class="bg-gray-800 text-white p-4 rounded overflow-x-auto"><code>X-API-Key: {{ control.apiKey || 'YOUR_API_KEY' }}</code></pre>
            <p class="my-2 text-center text-gray-500">{{ 'api_keys.usage.headers.or' | translate }}</p>
            <pre class="bg-gray-800 text-white p-4 rounded overflow-x-auto"><code>Authorization: Bearer {{ control.apiKey || 'YOUR_API_KEY' }}</code></pre>
          </div>

          <div class="mb-6">
            <h3 class="font-bold mb-2">{{ 'api_keys.usage.query.heading' | translate }}</h3>
            <pre class="bg-gray-800 text-white p-4 rounded overflow-x-auto"><code>GET /api/v1/masters/crops?api_key={{ control.apiKey || 'YOUR_API_KEY' }}</code></pre>
          </div>

          <div class="mt-6">
            <a href="/api/docs" target="_blank" class="highlight-box-button">
              {{ 'api_keys.usage.reference_button' | translate }}
            </a>
          </div>
        </div>
      }
    </div>
  `,
  styles: [`
    .form-group {
      margin-bottom: 1.5rem;
    }
    pre {
      font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace;
    }
  `]
})
export class ApiKeyComponent implements ApiKeyView, OnInit {
  private readonly loadUseCase = inject(LoadApiKeyUseCase);
  private readonly generateUseCase = inject(GenerateApiKeyUseCase);
  private readonly regenerateUseCase = inject(RegenerateApiKeyUseCase);
  private readonly presenter = inject(ApiKeyPresenter);

  private _control: ApiKeyViewState = initialControl;
  get control(): ApiKeyViewState {
    return this._control;
  }
  set control(value: ApiKeyViewState) {
    this._control = value;
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    this.loadUseCase.execute({});
  }

  generate(): void {
    if (this.control.generating) return;
    this.control = { ...this.control, generating: true, error: null };
    this.generateUseCase.execute({});
  }

  regenerate(): void {
    if (this.control.generating) return;
    if (!confirm('現在のAPIキーは無効になります。本当によろしいですか？')) return;
    this.control = { ...this.control, generating: true, error: null };
    this.regenerateUseCase.execute({});
  }

  copyToClipboard(): void {
    navigator.clipboard.writeText(this.control.apiKey).then(() => {
      this.control = {
        ...this.control,
        copyButtonLabel: 'コピーしました！'
      };
      setTimeout(() => {
        this.control = { ...this.control, copyButtonLabel: 'コピー' };
      }, 2000);
    });
  }
}
