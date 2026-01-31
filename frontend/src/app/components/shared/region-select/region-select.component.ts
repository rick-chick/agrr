import { Component, Input, Output, EventEmitter } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { TranslateModule } from '@ngx-translate/core';

@Component({
  selector: 'app-region-select',
  standalone: true,
  imports: [CommonModule, FormsModule, TranslateModule],
  template: `
    <label class="form-card__field" [for]="id">
      <span class="form-card__field-label">{{ 'crops.form.region_label' | translate }}</span>
      <select
        [id]="id"
        [name]="name"
        [required]="required"
        [disabled]="disabled"
        [(ngModel)]="regionValue"
        (ngModelChange)="onRegionChange($event)"
      >
        <option value="">{{ 'crops.form.region_blank' | translate }}</option>
        <option value="jp">{{ 'crops.form.region_jp' | translate }}</option>
        <option value="us">{{ 'crops.form.region_us' | translate }}</option>
        <option value="in">{{ 'crops.form.region_in' | translate }}</option>
      </select>
    </label>
  `,
  styleUrl: './region-select.component.css'
})
export class RegionSelectComponent {
  @Input() region: string | null | undefined = null;
  @Input() required = false;
  @Input() disabled = false;
  @Input() id = 'region';
  @Input() name = 'region';

  @Output() regionChange = new EventEmitter<string | null>();

  get regionValue(): string | null | undefined {
    return this.region;
  }

  set regionValue(value: string | null | undefined) {
    this.region = value ?? null;
    this.regionChange.emit(this.region);
  }

  onRegionChange(value: string | null | undefined): void {
    this.regionChange.emit(value ?? null);
  }
}