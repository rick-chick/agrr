import { Component, Input } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import type { PlanCreateReadiness } from '../../domain/plans/plan-create-readiness';

@Component({
  selector: 'app-plan-create-readiness-summary',
  standalone: true,
  imports: [CommonModule, RouterLink, TranslateModule],
  styleUrls: ['./plan-create-readiness-summary.component.css'],
  template: `
    @if (readiness) {
      <div class="blueprint-readiness plan-create-readiness" role="status">
        <p class="blueprint-readiness__title">{{ 'plans.new.readiness.title' | translate }}</p>
        <ul class="blueprint-readiness__list">
          <li [class.blueprint-readiness__item--ok]="readiness.fieldsReady">
            @if (readiness.fieldsReady) {
              <span>{{ 'plans.new.readiness.fields_ready' | translate: { count: readiness.fieldCount } }}</span>
            } @else {
              <span>{{ 'plans.new.readiness.fields_missing' | translate }}</span>
              <a class="blueprint-readiness__link" [routerLink]="['/farms', readiness.farmId]">
                {{ 'plans.new.readiness.fields_action' | translate }}
              </a>
            }
          </li>
          <li [class.blueprint-readiness__item--ok]="readiness.weatherReady">
            @if (readiness.weatherReady) {
              <span>{{ 'plans.new.readiness.weather_ready' | translate }}</span>
            } @else {
              <span>{{ weatherStatusLabelKey | translate }}</span>
              <a class="blueprint-readiness__link" [routerLink]="['/farms', readiness.farmId]">
                {{ 'plans.new.readiness.weather_action' | translate }}
              </a>
            }
          </li>
          <li [class.blueprint-readiness__item--ok]="readiness.cropsReady">
            @if (readiness.cropsReady) {
              <span>{{ 'plans.new.readiness.crops_ready' | translate }}</span>
            } @else if (readiness.cropSummaries.length === 0) {
              <span>{{ 'plans.new.readiness.crops_missing' | translate }}</span>
              <a class="blueprint-readiness__link" routerLink="/crops/new">
                {{ 'plans.new.readiness.crops_action' | translate }}
              </a>
            } @else {
              <span>{{ 'plans.new.readiness.crops_incomplete' | translate }}</span>
              <a class="blueprint-readiness__link" routerLink="/crops">
                {{ 'plans.new.readiness.crops_action' | translate }}
              </a>
            }
          </li>
        </ul>
        @if (readiness.cropSummaries.length > 0 && !readiness.cropsReady) {
          <ul class="plan-create-readiness__crop-list">
            @for (crop of readiness.cropSummaries; track crop.cropId) {
              <li [class.blueprint-readiness__item--ok]="crop.ready">
                <span>{{ crop.name }}</span>
                @if (!crop.ready) {
                  <a
                    class="blueprint-readiness__link"
                    [routerLink]="['/crops', crop.cropId, 'task_schedule_blueprints']"
                  >
                    {{ 'plans.new.readiness.crop_blueprint_action' | translate }}
                  </a>
                }
              </li>
            }
          </ul>
        }
      </div>
    }
  `
})
export class PlanCreateReadinessSummaryComponent {
  @Input() readiness: PlanCreateReadiness | null = null;

  get weatherStatusLabelKey(): string {
    const status = this.readiness?.weatherStatus;
    if (status == null) {
      return 'plans.new.readiness.weather_missing';
    }
    return `models.farm.weather_status.${status}`;
  }
}
