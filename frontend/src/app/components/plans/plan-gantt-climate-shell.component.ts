import { Component, Input } from '@angular/core';
import { CommonModule } from '@angular/common';
import { TranslateModule } from '@ngx-translate/core';
import { CultivationPlanData } from '../../domain/plans/cultivation-plan-data';
import { GanttVisibleRange } from '../../domain/plans/gantt-chart-layout';
import { GanttChartComponent } from './gantt-chart.component';
import { PlanFieldClimateComponent } from './plan-field-climate.component';

export type CultivationSelectionEvent = {
  cultivationId: number;
  planType: 'private' | 'public';
};

/**
 * 計画詳細・public 結果で共有するガント＋気候パネル UI。
 * 栽培選択・表示期間の View 状態はここに閉じ、親はデータ取得と画面固有アクションのみ担う。
 */
@Component({
  selector: 'app-plan-gantt-climate-shell',
  standalone: true,
  imports: [CommonModule, GanttChartComponent, PlanFieldClimateComponent, TranslateModule],
  template: `
    <div class="plan-detail__layout">
      <div class="plan-detail__pane plan-detail__gantt">
        <app-gantt-chart
          [data]="data"
          [planType]="planType"
          (cultivationSelected)="handleCultivationSelection($event)"
          (visibleRangeChange)="handleVisibleRangeUpdate($event)"
        />
      </div>

      <div
        class="plan-detail__pane plan-detail__climate-panel"
        [class.plan-detail__climate-panel--open]="selectedCultivationId !== null"
      >
        @if (selectedCultivationId) {
          <app-plan-field-climate
            [fieldCultivationId]="selectedCultivationId"
            [planType]="selectedPlanType"
            [displayStartDate]="visibleRangeStartDate"
            [displayEndDate]="visibleRangeEndDate"
            (close)="closeClimatePanel()"
          />
        } @else {
          <p class="plan-detail__climate-placeholder">
            {{ 'plans.detail.select_cultivation_hint' | translate }}
          </p>
        }
      </div>
    </div>
  `
})
export class PlanGanttClimateShellComponent {
  @Input({ required: true }) data!: CultivationPlanData;
  @Input() planType: 'private' | 'public' = 'private';

  selectedCultivationId: number | null = null;
  selectedPlanType: 'private' | 'public' = this.planType;
  visibleRangeStartDate: string | null = null;
  visibleRangeEndDate: string | null = null;

  handleCultivationSelection(event: CultivationSelectionEvent): void {
    const alreadySelected =
      this.selectedCultivationId === event.cultivationId &&
      this.selectedPlanType === event.planType;

    if (alreadySelected) {
      this.closeClimatePanel();
      return;
    }

    this.selectedCultivationId = event.cultivationId;
    this.selectedPlanType = event.planType;
  }

  closeClimatePanel(): void {
    this.selectedCultivationId = null;
    this.selectedPlanType = this.planType;
  }

  handleVisibleRangeUpdate(range: GanttVisibleRange): void {
    this.visibleRangeStartDate = this.toIsoDate(range.startDate);
    this.visibleRangeEndDate = this.toIsoDate(range.endDate);
  }

  private toIsoDate(value: Date): string {
    const year = value.getFullYear();
    const month = (value.getMonth() + 1).toString().padStart(2, '0');
    const day = value.getDate().toString().padStart(2, '0');
    return `${year}-${month}-${day}`;
  }
}
