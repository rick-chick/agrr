import { Component } from '@angular/core';
import { TranslateModule } from '@ngx-translate/core';

export interface PublicPlanPrivateValueFeature {
  featureKey: 'weather_reschedule' | 'learn_loop' | 'work_gdd_comparison';
  titleKey: string;
  descriptionKey: string;
}

export function buildPublicPlanPrivateValueFeatures(): PublicPlanPrivateValueFeature[] {
  return [
    {
      featureKey: 'weather_reschedule',
      titleKey: 'public_plans.results.private_value_preview.weather_reschedule.title',
      descriptionKey:
        'public_plans.results.private_value_preview.weather_reschedule.description'
    },
    {
      featureKey: 'learn_loop',
      titleKey: 'public_plans.results.private_value_preview.learn_loop.title',
      descriptionKey: 'public_plans.results.private_value_preview.learn_loop.description'
    },
    {
      featureKey: 'work_gdd_comparison',
      titleKey: 'public_plans.results.private_value_preview.work_gdd_comparison.title',
      descriptionKey:
        'public_plans.results.private_value_preview.work_gdd_comparison.description'
    }
  ];
}

@Component({
  selector: 'app-public-plan-private-value-preview',
  standalone: true,
  imports: [TranslateModule],
  template: `
    <details class="public-plan-private-value-preview">
      <summary class="public-plan-private-value-preview__summary">
        {{ 'public_plans.results.private_value_preview.toggle_summary' | translate }}
      </summary>
      <div class="public-plan-private-value-preview__content">
        <p class="public-plan-private-value-preview__lead">
          {{ 'public_plans.results.private_value_preview.lead' | translate }}
        </p>
        <ul class="public-plan-private-value-preview__list" role="list">
          @for (feature of features; track feature.featureKey) {
            <li class="public-plan-private-value-preview__item">
              <h3 class="public-plan-private-value-preview__item-title">
                {{ feature.titleKey | translate }}
              </h3>
              <p class="public-plan-private-value-preview__item-description">
                {{ feature.descriptionKey | translate }}
              </p>
            </li>
          }
        </ul>
      </div>
    </details>
  `,
  styleUrls: ['./public-plan-private-value-preview.component.css']
})
export class PublicPlanPrivateValuePreviewComponent {
  readonly features = buildPublicPlanPrivateValueFeatures();
}
