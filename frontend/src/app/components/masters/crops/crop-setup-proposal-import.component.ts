import { Component, OnInit, inject, ChangeDetectorRef, DestroyRef } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { MasterContextHeaderComponent } from '../master-context-header/master-context-header.component';
import { MasterContextCrumb } from '../master-context-header/master-context-crumb';
import {
  CropSetupProposalImportView,
  CropSetupProposalImportViewState
} from './crop-setup-proposal-import.view';
import { CropSetupProposalImportPresenter,
  CROP_SETUP_PROPOSAL_IMPORT_PROVIDERS
} from '../../../usecase/crops/crop-setup-proposal-import.providers';
import { LoadCropForEditUseCase } from '../../../usecase/crops/load-crop-for-edit.usecase';
import { DryRunCropSetupProposalUseCase } from '../../../usecase/crops/dry-run-crop-setup-proposal.usecase';
import { ApplyCropSetupProposalUseCase } from '../../../usecase/crops/apply-crop-setup-proposal.usecase';
import { CropSetupProposalBody } from '../../../domain/crops/crop-setup-proposal';
import { blueprintTimingPrefillStorageKey, blueprintTimingLearnApplyContextStorageKey, type BlueprintTimingLearnApplyContext } from '../../../domain/plans/blueprint-timing-adjustment-proposal';
import { parseFromPlanId } from '../../../domain/crops/parse-from-plan-id';
import { parsePlanWizardReturnTab, type PlanWizardReturnTab } from '../../../domain/crops/plan-wizard-context';
import { bpTimingProposalKey, markProposalApplied } from '../../../domain/plans/learn-proposal-application-progress';
import {
  learnPostMasterPath,
  learnPostMasterQueryParams,
  writeLearnPostMasterContext
} from '../../../domain/plans/learn-post-master-follow-up';
import { setupProposalValidationErrorI18nKey } from '../../../core/setup-proposal-validation-error-i18n';

const initialControl: CropSetupProposalImportViewState = {
  loading: true,
  submitting: false,
  applying: false,
  error: null,
  cropName: null,
  jsonInput: '',
  phase: 'input',
  validationErrors: [],
  normalizedPreview: null,
  parsedProposal: null
};

function isProposalBody(value: unknown): value is CropSetupProposalBody {
  if (!value || typeof value !== 'object') return false;
  const record = value as Record<string, unknown>;
  if (record['intent'] === 'blueprint_timing_patch') {
    return Array.isArray(record['task_schedule_blueprints']);
  }
  return (
    Array.isArray(record['stages']) &&
    Array.isArray(record['agricultural_tasks']) &&
    Array.isArray(record['task_schedule_blueprints'])
  );
}

@Component({
  selector: 'app-crop-setup-proposal-import',
  standalone: true,
  imports: [CommonModule, FormsModule, TranslateModule, RouterLink, MasterContextHeaderComponent],
  providers: [...CROP_SETUP_PROPOSAL_IMPORT_PROVIDERS],
  template: `
    <div class="page-main">
      <app-master-context-header [crumbs]="contextCrumbs" />
      <section class="form-card" aria-labelledby="import-heading">
        @if (control.loading) {
          <h2 id="import-heading" class="form-card__title">{{ 'common.loading' | translate }}</h2>
          <p class="master-loading">{{ 'common.loading' | translate }}</p>
        } @else {
          <h2 id="import-heading" class="form-card__title">
            {{ 'crops.setup_proposal_import.title' | translate:{ name: control.cropName } }}
          </h2>
          <p class="crop-setup-proposal-import__lead">
            {{ 'crops.setup_proposal_import.lead' | translate }}
          </p>

          <ul class="crop-setup-proposal-import__l0-notice" aria-label="{{ 'crops.setup_proposal_import.l0_notice_label' | translate }}">
            <li>{{ 'crops.setup_proposal_import.l0_notice_ai_source' | translate }}</li>
            <li>{{ 'crops.setup_proposal_import.l0_notice_dry_run' | translate }}</li>
            <li>{{ 'crops.setup_proposal_import.l0_notice_overwrite' | translate }}</li>
          </ul>

          @if (control.error) {
            <p class="master-loading master-error" role="alert">{{ control.error | translate }}</p>
            <p class="crop-setup-proposal-import__recovery-hint">
              {{ 'crops.setup_proposal_import.fix_and_preview_hint' | translate }}
            </p>
          }

          <label for="proposal-json" class="form-card__field">
            <span class="form-card__field-label">{{ 'crops.setup_proposal_import.json_label' | translate }}</span>
            <div class="crop-setup-proposal-import__input-actions">
              <button
                type="button"
                class="btn btn-secondary"
                (click)="triggerFileSelect()"
                [disabled]="control.submitting || control.applying"
              >
                {{ 'crops.setup_proposal_import.choose_file' | translate }}
              </button>
              <button
                type="button"
                class="btn btn-secondary"
                (click)="pasteFromClipboard()"
                [disabled]="control.submitting || control.applying"
              >
                {{ 'crops.setup_proposal_import.paste_clipboard' | translate }}
              </button>
            </div>
            <input
              type="file"
              accept="application/json,.json"
              class="crop-setup-proposal-import__file-input"
              (change)="onFileSelected($event)"
            />
            <textarea
              id="proposal-json"
              name="proposalJson"
              class="crop-setup-proposal-import__json"
              [(ngModel)]="control.jsonInput"
              (ngModelChange)="onJsonInputChange()"
              [placeholder]="'crops.setup_proposal_import.json_placeholder' | translate"
              [disabled]="control.submitting || control.applying"
            ></textarea>
          </label>

          <div class="form-card__actions">
            <button
              type="button"
              class="btn btn-primary"
              (click)="previewProposal()"
              [disabled]="!control.jsonInput.trim() || control.submitting || control.applying"
            >
              {{
                (control.submitting
                  ? 'crops.setup_proposal_import.previewing'
                  : 'crops.setup_proposal_import.preview_button')
                  | translate
              }}
            </button>
          </div>

          @if (control.phase === 'validation_errors' && control.validationErrors.length) {
            <section aria-labelledby="validation-errors-heading">
              <h3 id="validation-errors-heading" class="crop-setup-proposal-import__section-title">
                {{ 'crops.setup_proposal_import.validation_errors_title' | translate }}
              </h3>
              <ul class="crop-setup-proposal-import__errors">
                @for (item of control.validationErrors; track item.path + item.message) {
                  <li>
                    <strong>{{ item.path }}</strong>:
                    {{ validationErrorMessageKey(item) | translate }}
                  </li>
                }
              </ul>
              <p class="crop-setup-proposal-import__recovery-hint">
                {{ 'crops.setup_proposal_import.fix_and_preview_hint' | translate }}
              </p>
            </section>
          }

          @if (control.phase === 'success') {
            <section aria-labelledby="success-heading" class="crop-setup-proposal-import__success">
              <h3 id="success-heading" class="crop-setup-proposal-import__section-title">
                {{ 'crops.setup_proposal_import.success_title' | translate }}
              </h3>
              <p>{{ 'crops.setup_proposal_import.success_message' | translate }}</p>
              <div class="form-card__actions">
                <a
                  [routerLink]="['/crops', cropId]"
                  class="btn btn-primary crop-setup-proposal-import__back-to-crop"
                >
                  {{ 'crops.setup_proposal_import.back_to_crop' | translate }}
                </a>
              </div>
            </section>
          }

          @if (control.phase === 'preview' && control.normalizedPreview) {
            <section aria-labelledby="preview-heading">
              <h3 id="preview-heading" class="crop-setup-proposal-import__section-title">
                {{ 'crops.setup_proposal_import.preview_title' | translate }}
              </h3>
              <pre class="crop-setup-proposal-import__preview">{{ control.normalizedPreview | json }}</pre>
              <div class="form-card__actions">
                <button
                  type="button"
                  class="btn btn-primary"
                  (click)="applyProposal()"
                  [disabled]="control.applying"
                >
                  {{
                    (control.applying
                      ? 'crops.setup_proposal_import.applying'
                      : 'crops.setup_proposal_import.apply_button')
                      | translate
                  }}
                </button>
              </div>
            </section>
          }
        }
      </section>
    </div>
  `,
  styleUrls: ['./crop-setup-proposal-import.component.css']
})
export class CropSetupProposalImportComponent implements CropSetupProposalImportView, OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly loadUseCase = inject(LoadCropForEditUseCase);
  private readonly dryRunUseCase = inject(DryRunCropSetupProposalUseCase);
  private readonly applyUseCase = inject(ApplyCropSetupProposalUseCase);
  private readonly presenter = inject(CropSetupProposalImportPresenter);
  private readonly cdr = inject(ChangeDetectorRef);
  private readonly destroyRef = inject(DestroyRef);
  private readonly translate = inject(TranslateService);

  fromPlanId: number | null = null;
  returnTab: PlanWizardReturnTab = 'task_schedule';

  validationErrorMessageKey(item: { path: string; message: string }): string {
    return setupProposalValidationErrorI18nKey(item);
  }

  private _control: CropSetupProposalImportViewState = initialControl;
  get control(): CropSetupProposalImportViewState {
    return this._control;
  }
  set control(value: CropSetupProposalImportViewState) {
    const wasLoading = this._control.loading;
    this._control = value;
    if (wasLoading && !value.loading && !value.error) {
      this.applyPrefillFromSession();
    }
    this.cdr.markForCheck();
  }

  get contextCrumbs(): MasterContextCrumb[] {
    const crumbs: MasterContextCrumb[] = [
      { labelKey: 'crops.index.title', routerLink: ['/crops'] }
    ];
    if (!this.control.loading && this.control.cropName) {
      crumbs.push({
        label: this.control.cropName,
        routerLink: ['/crops', this.cropId]
      });
    }
    crumbs.push({ labelKey: 'crops.setup_proposal_import.breadcrumb' });
    return crumbs;
  }

  get cropId(): number {
    return Number(this.route.snapshot.paramMap.get('id')) ?? 0;
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    this.fromPlanId = parseFromPlanId(this.route.snapshot.queryParamMap.get('fromPlan'));
    this.returnTab = parsePlanWizardReturnTab(this.route.snapshot.queryParamMap.get('returnTo'));
    this.route.paramMap.pipe(takeUntilDestroyed(this.destroyRef)).subscribe(() => {
      this.handleCropRouteChange();
    });
  }

  private handleCropRouteChange(): void {
    this.control = { ...initialControl };
    if (!this.cropId) {
      this.control = {
        ...initialControl,
        loading: false,
        error: 'crops.errors.invalid_id'
      };
      return;
    }
    this.loadUseCase.execute({ cropId: this.cropId });
  }

  private applyPrefillFromSession(): void {
    const stored = sessionStorage.getItem(blueprintTimingPrefillStorageKey(this.cropId));
    if (!stored) {
      return;
    }
    sessionStorage.removeItem(blueprintTimingPrefillStorageKey(this.cropId));
    try {
      const parsed: unknown = JSON.parse(stored);
      if (!isProposalBody(parsed)) {
        return;
      }
      this.control = {
        ...this.control,
        jsonInput: JSON.stringify(parsed, null, 2),
        parsedProposal: parsed,
        phase: 'input',
        error: null
      };
      this.dryRunUseCase.execute({ cropId: this.cropId, proposal: parsed });
    } catch {
      // ignore invalid prefill payload
    }
  }

  onJsonInputChange(): void {
    if (this.control.phase === 'input' && !this.control.parsedProposal) {
      return;
    }
    this.control = {
      ...this.control,
      phase: 'input',
      validationErrors: [],
      normalizedPreview: null,
      parsedProposal: null
    };
  }

  triggerFileSelect(): void {
    const input = document.querySelector<HTMLInputElement>(
      '.crop-setup-proposal-import__file-input'
    );
    input?.click();
  }

  onFileSelected(event: Event): void {
    const input = event.target as HTMLInputElement;
    const file = input.files?.[0];
    if (!file) return;
    const reader = new FileReader();
    reader.onload = () => {
      const text = typeof reader.result === 'string' ? reader.result : '';
      this.control = { ...this.control, jsonInput: text, phase: 'input', validationErrors: [], normalizedPreview: null };
      input.value = '';
    };
    reader.readAsText(file);
  }

  async pasteFromClipboard(): Promise<void> {
    try {
      const text = await navigator.clipboard.readText();
      this.control = {
        ...this.control,
        jsonInput: text,
        phase: 'input',
        validationErrors: [],
        normalizedPreview: null
      };
    } catch {
      this.control = {
        ...this.control,
        error: this.translate.instant('crops.setup_proposal_import.clipboard_error')
      };
    }
  }

  previewProposal(): void {
    const proposal = this.parseProposalInput();
    if (!proposal) return;
    this.control = { ...this.control, parsedProposal: proposal };
    this.dryRunUseCase.execute({ cropId: this.cropId, proposal });
  }

  applyProposal(): void {
    const proposal = this.parseProposalInput();
    if (!proposal) return;
    this.applyUseCase.execute({
      cropId: this.cropId,
      proposal,
      onSuccess: () => {
        if (this.navigateToLearnPostMasterIfNeeded()) {
          return;
        }
        this.control = { ...this.control, phase: 'success' };
      }
    });
  }

  private navigateToLearnPostMasterIfNeeded(): boolean {
    if (this.returnTab !== 'learn' || this.fromPlanId == null) {
      return false;
    }
    const applyContext = this.readBlueprintTimingApplyContext();
    if (!applyContext) {
      return false;
    }
    const key = bpTimingProposalKey(this.cropId, applyContext.category);
    markProposalApplied(this.fromPlanId, key);
    writeLearnPostMasterContext(this.fromPlanId, {
      kind: 'bp_timing',
      cropName: applyContext.cropName,
      detailLabel: applyContext.category
    });
    sessionStorage.removeItem(
      blueprintTimingLearnApplyContextStorageKey(this.fromPlanId, this.cropId)
    );
    void this.router.navigate(learnPostMasterPath(this.fromPlanId), {
      queryParams: learnPostMasterQueryParams()
    });
    return true;
  }

  private readBlueprintTimingApplyContext(): BlueprintTimingLearnApplyContext | null {
    if (this.fromPlanId == null) {
      return null;
    }
    const raw = sessionStorage.getItem(
      blueprintTimingLearnApplyContextStorageKey(this.fromPlanId, this.cropId)
    );
    if (!raw) {
      return null;
    }
    try {
      const parsed: unknown = JSON.parse(raw);
      if (!parsed || typeof parsed !== 'object') {
        return null;
      }
      const record = parsed as Record<string, unknown>;
      if (typeof record['cropName'] !== 'string' || typeof record['category'] !== 'string') {
        return null;
      }
      return { cropName: record['cropName'], category: record['category'] };
    } catch {
      return null;
    }
  }

  private parseProposalInput(): CropSetupProposalBody | null {
    try {
      const parsed: unknown = JSON.parse(this.control.jsonInput);
      if (!isProposalBody(parsed)) {
        this.control = {
          ...this.control,
          error: 'crops.setup_proposal_import.invalid_shape'
        };
        return null;
      }
      this.control = { ...this.control, error: null };
      return parsed;
    } catch {
      this.control = {
        ...this.control,
        error: 'crops.setup_proposal_import.invalid_json'
      };
      return null;
    }
  }
}
