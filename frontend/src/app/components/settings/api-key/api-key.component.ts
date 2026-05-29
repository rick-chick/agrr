import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { ApiKeyView, ApiKeyViewState } from './api-key.view';
import { LoadApiKeyUseCase } from '../../../usecase/api-keys/load-api-key.usecase';
import { GenerateApiKeyUseCase } from '../../../usecase/api-keys/generate-api-key.usecase';
import { RegenerateApiKeyUseCase } from '../../../usecase/api-keys/regenerate-api-key.usecase';
import { ApiKeyPresenter, API_KEY_PROVIDERS } from '../../../usecase/api-keys/api-key.providers';

const initialControl: ApiKeyViewState = {
  loading: true,
  error: null,
  apiKey: '',
  copyButtonLabel: '',
  generating: false
};

@Component({
  selector: 'app-api-key',
  standalone: true,
  imports: [CommonModule, FormsModule, TranslateModule],
  providers: [...API_KEY_PROVIDERS],
  template: `
    <div class="page-content-container">
      <header class="page-header">
        <h1>{{ 'api_keys.title' | translate }}</h1>
      </header>

      <div class="info-box">
        <p class="info-box-content">{{ 'api_keys.warning' | translate }}</p>

        @if (control.apiKey) {
          <div class="form-group">
            <label class="form-group-label" for="api-key-value">{{ 'api_keys.label' | translate }}</label>
            <div class="api-key-input-row">
              <input
                id="api-key-value"
                type="text"
                class="api-key-input"
                [value]="control.apiKey"
                readonly
              >
              <button type="button" class="btn-secondary" (click)="copyToClipboard()">
                {{ control.copyButtonLabel }}
              </button>
            </div>
          </div>

          <div class="api-key-actions">
            <button
              type="button"
              class="btn-primary"
              (click)="regenerate()"
              [disabled]="control.generating"
            >
              {{ 'api_keys.actions.regenerate' | translate }}
            </button>
          </div>
        } @else {
          <div class="api-key-notice">
            <p>{{ 'api_keys.notices.missing' | translate }}</p>
          </div>

          <button
            type="button"
            class="btn-primary"
            (click)="generate()"
            [disabled]="control.generating"
          >
            {{ 'api_keys.actions.generate' | translate }}
          </button>
        }

        @if (control.error) {
          <p class="api-key-error" role="alert">{{ control.error }}</p>
        }
      </div>

      @if (control.loading) {
        <p class="master-loading">{{ 'common.loading' | translate }}</p>
      } @else {
        <div class="info-box info-box--usage">
          <h2 class="info-box-title">{{ 'api_keys.usage.heading' | translate }}</h2>

          <div class="usage-section">
            <h3 class="usage-section-title">{{ 'api_keys.usage.headers.header' | translate }}</h3>
            <pre class="api-key-code"><code>X-API-Key: {{ control.apiKey || 'YOUR_API_KEY' }}</code></pre>
            <p class="usage-or">{{ 'api_keys.usage.headers.or' | translate }}</p>
            <pre class="api-key-code"><code>Authorization: Bearer {{ control.apiKey || 'YOUR_API_KEY' }}</code></pre>
          </div>

          <div class="usage-section">
            <h3 class="usage-section-title">{{ 'api_keys.usage.query.heading' | translate }}</h3>
            <pre class="api-key-code"><code>GET /api/v1/masters/crops?api_key={{ control.apiKey || 'YOUR_API_KEY' }}</code></pre>
          </div>

          <div class="api-key-actions">
            <a href="/api/docs" target="_blank" rel="noopener noreferrer" class="highlight-box-button">
              {{ 'api_keys.usage.reference_button' | translate }}
            </a>
          </div>
        </div>
      }
    </div>
  `,
  styleUrls: ['./api-key.component.css']
})
export class ApiKeyComponent implements ApiKeyView, OnInit {
  private readonly loadUseCase = inject(LoadApiKeyUseCase);
  private readonly generateUseCase = inject(GenerateApiKeyUseCase);
  private readonly regenerateUseCase = inject(RegenerateApiKeyUseCase);
  private readonly presenter = inject(ApiKeyPresenter);
  private readonly cdr = inject(ChangeDetectorRef);
  private readonly translate = inject(TranslateService);

  private _control: ApiKeyViewState = initialControl;
  get control(): ApiKeyViewState {
    return this._control;
  }
  set control(value: ApiKeyViewState) {
    this._control = value;
    this.cdr.markForCheck();
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    this.control = {
      ...this.control,
      copyButtonLabel: this.translate.instant('api_keys.copy.button')
    };
    this.loadUseCase.execute({});
  }

  generate(): void {
    if (this.control.generating) return;
    this.control = { ...this.control, generating: true, error: null };
    this.generateUseCase.execute({});
  }

  regenerate(): void {
    if (this.control.generating) return;
    if (!confirm(this.translate.instant('api_keys.actions.regenerate_confirm'))) return;
    this.control = { ...this.control, generating: true, error: null };
    this.regenerateUseCase.execute({});
  }

  copyToClipboard(): void {
    navigator.clipboard.writeText(this.control.apiKey).then(() => {
      this.control = {
        ...this.control,
        copyButtonLabel: this.translate.instant('api_keys.copy.success')
      };
      setTimeout(() => {
        this.control = { ...this.control, copyButtonLabel: this.translate.instant('api_keys.copy.button') };
      }, 2000);
    });
  }
}
