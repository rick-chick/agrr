import { Component, EventEmitter, Input, Output } from '@angular/core';
import { CommonModule } from '@angular/common';
import { TranslateModule } from '@ngx-translate/core';
import { Farm } from '../../../domain/farms/farm';

export type FarmSelectionCardsState = 'loading' | 'empty' | 'error' | 'ready';

@Component({
  selector: 'app-farm-selection-cards',
  standalone: true,
  imports: [CommonModule, TranslateModule],
  template: `
    <div data-testid="farm-selection-cards" class="farm-selection-cards">
      @switch (state) {
        @case ('loading') {
          <p class="muted master-loading">{{ loadingKey | translate }}</p>
        }
        @case ('empty') {
          <p class="muted farm-selection-empty">{{ emptyKey | translate }}</p>
        }
        @case ('error') {
          <p class="error-message">{{ errorText ?? (errorKey | translate) }}</p>
          <button type="button" class="btn btn-secondary mt-2" (click)="retry.emit()">
            {{ 'entrySchedule.retry' | translate }}
          </button>
        }
        @case ('ready') {
          <div class="enhanced-grid" role="list">
            @for (farm of farms; track farm.id) {
              <div
                class="enhanced-selection-card"
                [class.active]="selectedFarmId === farm.id"
                (click)="farmSelect.emit(farm)"
                (keydown.enter)="farmSelect.emit(farm)"
                (keydown.space)="farmSelect.emit(farm); $event.preventDefault()"
                tabindex="0"
                role="listitem"
                [attr.aria-pressed]="selectedFarmId === farm.id"
              >
                <div class="enhanced-card-icon" aria-hidden="true">🌏</div>
                <div class="enhanced-card-title">{{ farmDisplayNames[farm.id] ?? farm.name }}</div>
              </div>
            }
          </div>
        }
      }
    </div>
  `,
  styleUrls: ['../../public-plans/public-plan.component.css'],
})
export class FarmSelectionCardsPattern {
  @Input() state: FarmSelectionCardsState = 'loading';
  @Input() farms: Farm[] = [];
  @Input() selectedFarmId: number | null = null;
  @Input() errorKey = 'entrySchedule.error';
  /** When set, shown as-is instead of translating errorKey. */
  @Input() errorText: string | null = null;
  @Input() loadingKey = 'entrySchedule.loading';
  @Input() emptyKey = 'entrySchedule.noFarms';
  /** Optional per-farm display labels (e.g. localized reference farm names). */
  @Input() farmDisplayNames: Record<number, string> = {};
  @Output() farmSelect = new EventEmitter<Farm>();
  @Output() retry = new EventEmitter<void>();
}
