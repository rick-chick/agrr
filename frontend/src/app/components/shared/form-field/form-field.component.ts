import { Component, EventEmitter, Input, Output } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { TranslateModule } from '@ngx-translate/core';
import {
  formCardAriaDescribedby,
  formCardAriaInvalid,
  formCardFieldErrorId,
  formCardFieldShowsError,
  formCardRequiredValueInvalid
} from '../../../core/form-card-field-a11y';

/**
 * Shared form-card field for text, textarea, and generic select.
 *
 * Region-specific selects use `app-region-select` (admin region picker with fixed options).
 * Use this component for arbitrary labels/inputs within master form-card layouts.
 */
export interface FormFieldSelectOption {
  value: string;
  labelKey: string;
}

@Component({
  selector: 'app-form-field',
  standalone: true,
  imports: [CommonModule, FormsModule, TranslateModule],
  template: `
    <label class="form-card__field" [for]="inputId">
      <span class="form-card__field-label">{{ labelKey | translate }}</span>
      @switch (fieldType) {
        @case ('textarea') {
          <textarea
            [id]="inputId"
            [name]="effectiveName"
            [required]="required"
            [class.form-card__input--invalid]="showError"
            [attr.aria-invalid]="ariaInvalid"
            [attr.aria-describedby]="ariaDescribedby"
            [(ngModel)]="value"
            (ngModelChange)="onValueChange($event)"
          ></textarea>
        }
        @case ('select') {
          <select
            class="form-card__select"
            [id]="inputId"
            [name]="effectiveName"
            [required]="required"
            [class.form-card__input--invalid]="showError"
            [attr.aria-invalid]="ariaInvalid"
            [attr.aria-describedby]="ariaDescribedby"
            [(ngModel)]="value"
            (ngModelChange)="onValueChange($event)"
          >
            @for (option of selectOptions; track option.value) {
              <option [value]="option.value">{{ option.labelKey | translate }}</option>
            }
          </select>
        }
        @default {
          <input
            [id]="inputId"
            [name]="effectiveName"
            [type]="inputType"
            [step]="step"
            [min]="min"
            [max]="max"
            [placeholder]="placeholderKey ? (placeholderKey | translate) : null"
            [required]="required"
            [class.form-card__input--invalid]="showError"
            [attr.aria-invalid]="ariaInvalid"
            [attr.aria-describedby]="ariaDescribedby"
            [(ngModel)]="value"
            (ngModelChange)="onValueChange($event)"
          />
        }
      }
      @if (showError) {
        <span [id]="errorElementId" class="form-card__field-error" role="alert">
          {{ errorKey | translate }}
        </span>
      }
    </label>
  `
})
export class FormFieldComponent {
  @Input({ required: true }) inputId!: string;
  @Input() name?: string;
  @Input({ required: true }) labelKey!: string;
  @Input() errorKey = 'common.form.required_field';
  @Input() required = false;
  @Input() formSubmitted = false;
  @Input() invalid?: boolean;
  @Input() fieldType: 'text' | 'textarea' | 'select' = 'text';
  @Input() inputType = 'text';
  @Input() step?: string;
  @Input() min?: string;
  @Input() max?: string;
  @Input() placeholderKey?: string;
  @Input() describedBy?: string;
  @Input() selectOptions: FormFieldSelectOption[] = [];

  @Input() value: string | number | null = '';
  @Output() valueChange = new EventEmitter<string | number | null>();

  get effectiveName(): string {
    return this.name ?? this.inputId;
  }

  get effectiveInvalid(): boolean {
    if (this.invalid !== undefined) {
      return this.invalid;
    }
    if (this.required) {
      return formCardRequiredValueInvalid(this.value);
    }
    return false;
  }

  get showError(): boolean {
    return formCardFieldShowsError(this.formSubmitted, this.effectiveInvalid);
  }

  get ariaInvalid(): true | null {
    return formCardAriaInvalid(this.formSubmitted, this.effectiveInvalid);
  }

  get ariaDescribedby(): string | null {
    const errorId = formCardAriaDescribedby(this.inputId, this.formSubmitted, this.effectiveInvalid);
    const extra = this.describedBy?.trim();
    if (extra && errorId) {
      return `${extra} ${errorId}`;
    }
    return extra || errorId;
  }

  get errorElementId(): string {
    return formCardFieldErrorId(this.inputId);
  }

  onValueChange(value: string | number | null): void {
    this.value = value;
    this.valueChange.emit(value);
  }
}
