import { Component, input, computed } from '@angular/core';
import { TranslateModule } from '@ngx-translate/core';
import { SkeletonComponent } from './skeleton.component';

@Component({
  selector: 'app-card-list-skeleton',
  standalone: true,
  imports: [SkeletonComponent, TranslateModule],
  template: `
    <ul
      class="card-list"
      role="list"
      aria-busy="true"
      [attr.aria-label]="'common.loading' | translate"
    >
      @for (row of rowIndexes(); track row) {
        <li class="card-list__item">
          <article class="item-card skeleton-card">
            <div class="item-card__body skeleton-card__body">
              <app-skeleton variant="title" />
              <app-skeleton variant="meta" />
            </div>
            <div class="item-card__actions skeleton-card__actions">
              <app-skeleton variant="button" />
              <app-skeleton variant="button" />
            </div>
          </article>
        </li>
      }
    </ul>
  `,
  styleUrls: ['./card-list-skeleton.component.css']
})
export class CardListSkeletonComponent {
  readonly count = input(3);

  readonly rowIndexes = computed(() => Array.from({ length: this.count() }, (_, index) => index));
}
