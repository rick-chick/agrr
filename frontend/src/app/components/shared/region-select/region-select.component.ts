import { Component, Input, Output, EventEmitter } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { TranslateModule } from '@ngx-translate/core';
import {
  formCardAriaDescribedby,
  formCardAriaInvalid,
  formCardFieldErrorId,
  formCardFieldShowsError
} from '../../../core/form-card-field-a11y';

@Component({
  selector: 'app-region-select',
  standalone: true,
  imports: [CommonModule, FormsModule, TranslateModule],
  template: `
    <div class="form-card__field">
      <label class="form-card__field-label" [for]="id">
        {{ 'shared.region_select.label' | translate }}
      </label>
      <select
        class="form-card__select"
        [class.form-card__input--invalid]="showError"
        [id]="id"
        [name]="name"
        [required]="required"
        [disabled]="disabled"
        [(ngModel)]="regionValue"
        (ngModelChange)="onRegionChange($event)"
        [attr.aria-invalid]="ariaInvalid"
        [attr.aria-describedby]="ariaDescribedby"
      >
        <option value="">{{ 'shared.region_select.blank' | translate }}</option>
        <option value="jp">{{ 'shared.region_select.jp' | translate }}</option>
        <option value="us">{{ 'shared.region_select.us' | translate }}</option>
        <option value="in">{{ 'shared.region_select.in' | translate }}</option>
      </select>
      @if (showError) {
        <span [id]="errorElementId" class="form-card__field-error" role="alert">
          {{ 'common.form.required_field' | translate }}
        </span>
      }
    </div>
  `,
  styleUrls: ['./region-select.component.css']
})
export class RegionSelectComponent {
  @Input() region: string | null | undefined = null;
  @Input() required = false;
  @Input() disabled = false;
  @Input() id = 'region';
  @Input() name = 'region';
  @Input() formSubmitted = false;
  @Input() invalid = false;

  @Output() regionChange = new EventEmitter<string | null>();

  get regionValue(): string | null | undefined {
    return this.region;
  }

  set regionValue(value: string | null | undefined) {
    this.region = value ?? null;
    this.regionChange.emit(this.region);
  }

  get showError(): boolean {
    return formCardFieldShowsError(this.formSubmitted, this.invalid);
  }

  get ariaInvalid(): true | null {
    return formCardAriaInvalid(this.formSubmitted, this.invalid);
  }

  get ariaDescribedby(): string | null {
    return formCardAriaDescribedby(this.id, this.formSubmitted, this.invalid);
  }

  get errorElementId(): string {
    return formCardFieldErrorId(this.id);
  }

  onRegionChange(value: string | null | undefined): void {
    this.regionChange.emit(value ?? null);
  }
}
