import { Component, EventEmitter, Input, Output } from '@angular/core';
import { Farm } from '../../../domain/farms/farm';

@Component({
  selector: 'app-farm-selection-cards',
  standalone: true,
  imports: [],
  styleUrls: ['../../public-plans/public-plan.component.css'],
  template: `
    <section
      class="selection-section"
      data-testid="farm-selection-cards"
      [attr.aria-labelledby]="headingId"
    >
      <h3 [id]="headingId">{{ heading }}</h3>
      <div class="enhanced-grid" role="list">
        @for (farm of farms; track farm.id) {
          <div
            class="enhanced-selection-card"
            [class.active]="selectedFarmId === farm.id"
            (click)="onSelect(farm)"
            (keydown.enter)="onSelect(farm)"
            (keydown.space)="onSelect(farm); $event.preventDefault()"
            tabindex="0"
            role="listitem button"
            [attr.aria-pressed]="selectedFarmId === farm.id"
            [attr.aria-label]="labelFor(farm)"
          >
            <div class="enhanced-card-icon" aria-hidden="true">🌏</div>
            <div class="enhanced-card-title">{{ labelFor(farm) }}</div>
          </div>
        }
      </div>
    </section>
  `,
})
export class FarmSelectionCardsComponent {
  @Input({ required: true }) farms: Farm[] = [];
  @Input() selectedFarmId: number | null = null;
  @Input({ required: true }) heading = '';
  @Input() headingId = 'farm-heading';
  @Input() farmLabel: ((farm: Farm) => string) | null = null;

  @Output() farmSelect = new EventEmitter<Farm>();

  labelFor(farm: Farm): string {
    return this.farmLabel ? this.farmLabel(farm) : farm.name;
  }

  onSelect(farm: Farm): void {
    this.farmSelect.emit(farm);
  }
}
