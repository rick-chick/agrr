import { Component, input } from '@angular/core';
import { TranslateModule } from '@ngx-translate/core';

@Component({
  selector: 'app-skeleton',
  standalone: true,
  imports: [TranslateModule],
  template: `
    <ul
      class="card-list skeleton-card-list"
      role="status"
      aria-busy="true"
      [attr.aria-label]="'common.loading' | translate"
    >
      @for (item of skeletonItems(); track item) {
        <li class="card-list__item">
          <div class="skeleton-card" aria-hidden="true">
            <div class="skeleton-card__body">
              <div class="skeleton-line skeleton-line--title skeleton-shimmer"></div>
              <div class="skeleton-line skeleton-line--meta skeleton-shimmer"></div>
            </div>
            <div class="skeleton-card__actions">
              <div class="skeleton-button skeleton-shimmer"></div>
              <div class="skeleton-button skeleton-shimmer"></div>
            </div>
          </div>
        </li>
      }
    </ul>
  `,
  styleUrls: ['./skeleton.component.css']
})
export class SkeletonComponent {
  readonly count = input(3);

  skeletonItems(): number[] {
    return Array.from({ length: this.count() }, (_, index) => index);
  }
}
