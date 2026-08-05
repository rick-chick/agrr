import { Component, input } from '@angular/core';

export type SkeletonVariant = 'block' | 'title' | 'meta' | 'button';

@Component({
  selector: 'app-skeleton',
  standalone: true,
  template: `
    <div
      class="skeleton skeleton--shimmer"
      [class.skeleton--title]="variant() === 'title'"
      [class.skeleton--meta]="variant() === 'meta'"
      [class.skeleton--button]="variant() === 'button'"
      aria-hidden="true"
    ></div>
  `,
  styleUrls: ['./skeleton.component.css']
})
export class SkeletonComponent {
  readonly variant = input<SkeletonVariant>('block');
}
