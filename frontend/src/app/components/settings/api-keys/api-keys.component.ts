import { ChangeDetectorRef, Component, OnInit, inject } from '@angular/core';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import {
  API_DOCS_URL,
  ApiKeyManagementService
} from '../../../services/api-key-management.service';
import { FlashMessageService } from '../../../services/flash-message.service';

@Component({
  selector: 'app-api-keys',
  standalone: true,
  imports: [TranslateModule],
  template: `
    <div class="page-content-container">
      <header class="page-header">
        <h1>{{ 'api_keys.title' | translate }}</h1>
      </header>

      <p class="page-description" [innerHTML]="'api_keys.description_html' | translate"></p>

      <div class="info-box">
        <p class="info-box-content">{{ 'api_keys.warning' | translate }}</p>

        @if (apiKey) {
          <div class="form-group">
            <label class="form-group-label" for="api-key-value">{{ 'api_keys.label' | translate }}</label>
            <div class="api-key-input-row">
              <input
                id="api-key-value"
                type="text"
                class="api-key-input"
                [value]="apiKey"
                readonly
              >
              <button type="button" class="btn-secondary" (click)="copyToClipboard()">
                {{ copyButtonLabel }}
              </button>
            </div>
          </div>

          <div class="api-key-actions">
            <button
              type="button"
              class="btn-primary"
              (click)="regenerate()"
              [disabled]="generating"
            >
              {{ 'api_keys.actions.regenerate' | translate }}
            </button>
          </div>
        } @else if (!loading) {
          <div class="api-key-notice">
            <p>{{ 'api_keys.notices.missing' | translate }}</p>
          </div>

          <button
            type="button"
            class="btn-primary"
            (click)="generate()"
            [disabled]="generating"
          >
            {{ 'api_keys.actions.generate' | translate }}
          </button>
        }

        @if (errorMessage) {
          <p class="api-key-error" role="alert">{{ errorMessage }}</p>
        }
      </div>

      @if (loading) {
        <p class="master-loading">{{ 'common.loading' | translate }}</p>
      } @else {
        <div class="info-box info-box--usage">
          <h2 class="info-box-title">{{ 'api_keys.usage.heading' | translate }}</h2>

          <div class="usage-section">
            <h3 class="usage-section-title">{{ 'api_keys.usage.headers.header' | translate }}</h3>
            <pre class="api-key-code"><code>X-API-Key: {{ apiKey || 'YOUR_API_KEY' }}</code></pre>
            <p class="usage-or">{{ 'api_keys.usage.headers.or' | translate }}</p>
            <pre class="api-key-code"><code>Authorization: Bearer {{ apiKey || 'YOUR_API_KEY' }}</code></pre>
          </div>

          <div class="usage-section">
            <h3 class="usage-section-title">{{ 'api_keys.usage.query.heading' | translate }}</h3>
            <pre class="api-key-code"><code>GET /api/v1/masters/crops?api_key={{ apiKey || 'YOUR_API_KEY' }}</code></pre>
          </div>

          <div class="usage-section">
            <h3 class="usage-section-title">{{ 'api_keys.usage.endpoints.heading' | translate }}</h3>
            <div
              class="usage-endpoints"
              [innerHTML]="'api_keys.usage.endpoints.list_html' | translate"
            ></div>
          </div>

          <div class="api-key-actions">
            <a
              [href]="apiDocsUrl"
              target="_blank"
              rel="noopener noreferrer"
              class="highlight-box-button"
            >
              {{ 'api_keys.usage.reference_button' | translate }}
            </a>
          </div>
        </div>
      }
    </div>
  `,
  styleUrls: ['./api-keys.component.css']
})
export class ApiKeysComponent implements OnInit {
  private readonly management = inject(ApiKeyManagementService);
  private readonly flash = inject(FlashMessageService);
  private readonly translate = inject(TranslateService);
  private readonly cdr = inject(ChangeDetectorRef);

  readonly apiDocsUrl = API_DOCS_URL;

  loading = true;
  generating = false;
  apiKey = '';
  errorMessage: string | null = null;
  copyButtonLabel = '';

  ngOnInit(): void {
    this.copyButtonLabel = this.translate.instant('api_keys.copy.button');
    this.loadCurrentKey();
  }

  generate(): void {
    if (this.generating) return;
    this.generating = true;
    this.errorMessage = null;
    this.management.generateKey().subscribe({
      next: (apiKey) => {
        this.apiKey = apiKey;
        this.generating = false;
        this.cdr.markForCheck();
        this.flash.show({ type: 'success', text: 'api_keys.flash.generate.success' });
      },
      error: () => {
        this.generating = false;
        this.cdr.markForCheck();
        this.flash.show({ type: 'error', text: 'api_keys.flash.generate.failure' });
      }
    });
  }

  regenerate(): void {
    if (this.generating) return;
    const confirmed = confirm(this.translate.instant('api_keys.actions.regenerate_confirm'));
    if (!confirmed) return;

    this.generating = true;
    this.errorMessage = null;
    this.management.regenerateKey().subscribe({
      next: (apiKey) => {
        this.apiKey = apiKey;
        this.generating = false;
        this.cdr.markForCheck();
        this.flash.show({ type: 'success', text: 'api_keys.flash.regenerate.success' });
      },
      error: () => {
        this.generating = false;
        this.cdr.markForCheck();
        this.flash.show({ type: 'error', text: 'api_keys.flash.regenerate.failure' });
      }
    });
  }

  copyToClipboard(): void {
    if (!this.apiKey || !navigator.clipboard?.writeText) {
      this.flash.show({ type: 'warning', text: 'api_keys.copy.failure' });
      return;
    }

    navigator.clipboard.writeText(this.apiKey).then(
      () => {
        this.copyButtonLabel = this.translate.instant('api_keys.copy.success');
        setTimeout(() => {
          this.copyButtonLabel = this.translate.instant('api_keys.copy.button');
        }, 2000);
      },
      () => {
        this.flash.show({ type: 'warning', text: 'api_keys.copy.failure' });
      }
    );
  }

  private loadCurrentKey(): void {
    this.loading = true;
    this.management.getCurrentKey().subscribe({
      next: (apiKey) => {
        this.apiKey = apiKey ?? '';
        this.loading = false;
        this.cdr.markForCheck();
      },
      error: (error: Error) => {
        this.errorMessage = error.message;
        this.loading = false;
        this.cdr.markForCheck();
      }
    });
  }
}
