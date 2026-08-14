import {
  ChangeDetectionStrategy,
  ChangeDetectorRef,
  Component,
  Input,
  OnInit,
  inject
} from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { formatIsoDateForDisplay } from '../../core/format-display-date';
import { localTodayIso } from '../../core/local-today';
import { PlanWorkMiniClimatePanelPresenter } from '../../adapters/plans/plan-work-mini-climate-panel.presenter';
import { PreviewWorkRowMiniClimateStateDto } from '../../usecase/plans/preview-work-row-mini-climate/preview-work-row-mini-climate.dtos';
import { PreviewWorkRowMiniClimateUseCase } from '../../usecase/plans/preview-work-row-mini-climate/preview-work-row-mini-climate.usecase';
import { PREVIEW_WORK_ROW_MINI_CLIMATE_PROVIDERS } from '../../usecase/plans/preview-work-row-mini-climate/preview-work-row-mini-climate.providers';

function emptyMiniClimateState(): PreviewWorkRowMiniClimateStateDto {
  return {
    cumulativeGdd: null,
    dailyWeather: [],
    startDate: '',
    endDate: '',
    loading: false
  };
}

@Component({
  selector: 'app-plan-work-mini-climate-panel',
  standalone: true,
  imports: [CommonModule, RouterLink, TranslateModule],
  providers: [...PREVIEW_WORK_ROW_MINI_CLIMATE_PROVIDERS],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <section
      class="plan-work-mini-climate"
      data-testid="work-row-mini-climate-panel"
      [attr.aria-label]="'plans.work.mini_climate.title' | translate"
    >
      @if (state.loading) {
        <p class="plan-work-mini-climate__loading">{{ 'plans.work.mini_climate.loading' | translate }}</p>
      } @else if (state.cumulativeGdd != null || state.dailyWeather.length > 0) {
        @if (state.cumulativeGdd != null) {
          <p class="plan-work-mini-climate__gdd">
            {{
              'plans.work.mini_climate.cumulative_gdd'
                | translate: { value: state.cumulativeGdd }
            }}
          </p>
        }
        @if (state.dailyWeather.length > 0) {
          <ul class="plan-work-mini-climate__weather-list">
            @for (day of state.dailyWeather; track day.date) {
              <li class="plan-work-mini-climate__weather-row">
                <span class="plan-work-mini-climate__weather-date">{{ displayDate(day.date) }}</span>
                <span class="plan-work-mini-climate__weather-temps">
                  {{
                    'plans.work.mini_climate.daily_weather'
                      | translate
                        : {
                            max: day.temperatureMax,
                            min: day.temperatureMin,
                            mean: day.temperatureMean
                          }
                  }}
                </span>
              </li>
            }
          </ul>
        }
        <a
          class="plan-work-mini-climate__workbench-link"
          data-testid="work-row-mini-climate-workbench-link"
          [routerLink]="['/plans', planId]"
          [queryParams]="{ field_cultivation_id: fieldCultivationId }"
        >
          {{ 'plans.work.mini_climate.workbench_link' | translate }}
        </a>
      } @else {
        <p class="plan-work-mini-climate__unavailable">
          {{ 'plans.work.mini_climate.unavailable' | translate }}
        </p>
      }
    </section>
  `,
  styleUrls: ['./plan-work-mini-climate-panel.component.css']
})
export class PlanWorkMiniClimatePanelComponent implements OnInit
{
  @Input({ required: true }) planId!: number;
  @Input({ required: true }) fieldCultivationId!: number;

  state: PreviewWorkRowMiniClimateStateDto = emptyMiniClimateState();

  private readonly previewUseCase = inject(PreviewWorkRowMiniClimateUseCase);
  private readonly presenter = inject(PlanWorkMiniClimatePanelPresenter);
  private readonly translate = inject(TranslateService);
  private readonly cdr = inject(ChangeDetectorRef);

  ngOnInit(): void {
    this.presenter.setOnUpdate((state) => {
      this.state = state;
      this.cdr.markForCheck();
    });
    this.loadClimate();
  }

  displayDate(isoDate: string): string {
    return formatIsoDateForDisplay(isoDate, this.translate.currentLang);
  }

  private loadClimate(): void {
    this.previewUseCase.execute({
      fieldCultivationId: this.fieldCultivationId,
      today: localTodayIso()
    });
  }
}
