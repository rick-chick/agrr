import { Component, computed, input } from '@angular/core';
import { TranslateModule } from '@ngx-translate/core';
import { SkeletonComponent } from './skeleton.component';

@Component({
  selector: 'app-detail-skeleton',
  standalone: true,
  imports: [SkeletonComponent, TranslateModule],
  template: `
    <section
      class="detail-card detail-skeleton"
      aria-busy="true"
      [attr.aria-label]="'common.loading' | translate"
    >
      <div class="detail-skeleton__title">
        <app-skeleton variant="title" />
      </div>
      <dl class="detail-card__list">
        @for (row of rowIndexes(); track row) {
          <div class="detail-row detail-skeleton__row">
            <div class="detail-skeleton__term">
              <app-skeleton variant="meta" />
            </div>
            <div class="detail-skeleton__value">
              <app-skeleton variant="block" />
            </div>
          </div>
        }
      </dl>
      <div class="detail-card__actions detail-skeleton__actions">
        <app-skeleton variant="button" />
        <app-skeleton variant="button" />
      </div>
    </section>
  `,
  styleUrls: ['./detail-skeleton.component.css']
})
export class DetailSkeletonComponent {
  readonly rowCount = input(4);

  readonly rowIndexes = computed(() =>
    Array.from({ length: this.rowCount() }, (_, index) => index)
  );
}
