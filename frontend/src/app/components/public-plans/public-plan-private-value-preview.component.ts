import { Component } from '@angular/core';
import { TranslateModule } from '@ngx-translate/core';
import { PUBLIC_PLAN_PRIVATE_VALUE_ITEMS } from '../../domain/public-plans/public-plan-results-upsell.content';

@Component({
  selector: 'app-public-plan-private-value-preview',
  standalone: true,
  imports: [TranslateModule],
  template: `
    <details class="public-plan-private-value-preview">
      <summary class="public-plan-private-value-preview__summary">
        {{
          'public_plans.results.private_value_preview.summary'
            | translate: { count: features.length }
        }}
      </summary>
      <div class="public-plan-private-value-preview__content">
        <p class="public-plan-private-value-preview__lead">
          {{ 'public_plans.results.private_value_preview.lead' | translate }}
        </p>
        <ul class="public-plan-private-value-preview__list" role="list">
          @for (feature of features; track feature.titleKey) {
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
  readonly features = PUBLIC_PLAN_PRIVATE_VALUE_ITEMS;
}
