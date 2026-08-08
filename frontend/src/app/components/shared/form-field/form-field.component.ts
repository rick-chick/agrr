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

/** Select option for `app-form-field` type="select". */
export interface FormFieldSelectOption {
  value: string;
  labelKey: string;
}

export type FormFieldType = 'text' | 'number' | 'textarea' | 'select';

/**
 * Shared form-card field with label, validation error, and aria-* wiring.
 *
 * Use `app-region-select` for the fixed region master dropdown (jp/us/in).
 * This component covers generic text, number, textarea, and arbitrary select options.
 */
@Component({
  selector: 'app-form-field',
  standalone: true,
  imports: [CommonModule, FormsModule, TranslateModule],
  template: `
    <label class="form-card__field" [for]="inputId">
      <span class="form-card__field-label">{{ labelKey | translate }}</span>
      @if (type === 'textarea') {
        <textarea
          [id]="inputId"
          [name]="fieldName"
          [required]="required"
          [disabled]="disabled"
          [placeholder]="placeholder"
          [class.form-card__input--invalid]="showError"
          [attr.aria-invalid]="ariaInvalid"
          [attr.aria-describedby]="ariaDescribedby"
          [ngModel]="value"
          (ngModelChange)="onValueChange($event)"
        ></textarea>
      } @else if (type === 'select') {
        <select
          class="form-card__select"
          [id]="inputId"
          [name]="fieldName"
          [required]="required"
          [disabled]="disabled"
          [class.form-card__input--invalid]="showError"
          [attr.aria-invalid]="ariaInvalid"
          [attr.aria-describedby]="ariaDescribedby"
          [ngModel]="value"
          (ngModelChange)="onValueChange($event)"
        >
          @for (option of options; track option.value) {
            <option [value]="option.value">{{ option.labelKey | translate }}</option>
          }
        </select>
      } @else {
        <input
          [id]="inputId"
          [name]="fieldName"
          [type]="type"
          [required]="required"
          [disabled]="disabled"
          [step]="step"
          [min]="min"
          [max]="max"
          [placeholder]="placeholder"
          [class.form-card__input--invalid]="showError"
          [attr.aria-invalid]="ariaInvalid"
          [attr.aria-describedby]="ariaDescribedby"
          [ngModel]="value"
          (ngModelChange)="onValueChange($event)"
        />
      }
      @if (showError) {
        <span [id]="errorElementId" class="form-card__field-error" role="alert">
          {{ errorKey | translate }}
        </span>
      }
    </label>
  `,
  styleUrls: ['./form-field.component.css']
})
export class FormFieldComponent {
  @Input({ required: true }) inputId!: string;
  @Input() name = '';
  @Input({ required: true }) labelKey!: string;

  get fieldName(): string {
    return this.name || this.inputId;
  }
  @Input() errorKey = 'common.form.required_field';
  @Input() type: FormFieldType = 'text';
  @Input() required = false;
  @Input() disabled = false;
  @Input() formSubmitted = false;
  @Input() invalid: boolean | null = null;
  @Input() describedBy: string | null = null;
  @Input() value: string | number | null = '';
  @Input() options: FormFieldSelectOption[] = [];
  @Input() step: string | number | null = null;
  @Input() min: string | number | null = null;
  @Input() max: string | number | null = null;
  @Input() placeholder = '';

  @Output() valueChange = new EventEmitter<string | number | null>();

  get isInvalid(): boolean {
    if (this.invalid !== null) {
      return this.invalid;
    }
    if (this.required) {
      return formCardRequiredValueInvalid(this.value);
    }
    return false;
  }

  get showError(): boolean {
    return formCardFieldShowsError(this.formSubmitted, this.isInvalid);
  }

  get ariaInvalid(): true | null {
    return formCardAriaInvalid(this.formSubmitted, this.isInvalid);
  }

  get ariaDescribedby(): string | null {
    const errorId = formCardAriaDescribedby(this.inputId, this.formSubmitted, this.isInvalid);
    if (errorId && this.describedBy) {
      return `${errorId} ${this.describedBy}`;
    }
    if (errorId) {
      return errorId;
    }
    return this.describedBy;
  }

  get errorElementId(): string {
    return formCardFieldErrorId(this.inputId);
  }

  onValueChange(value: string | number | null): void {
    this.value = value;
    this.valueChange.emit(value);
  }
}
