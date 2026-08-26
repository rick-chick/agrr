import { Component, Input } from '@angular/core';
import { CommonModule } from '@angular/common';
import { TranslateModule } from '@ngx-translate/core';

@Component({
  selector: 'app-app-shell',
  standalone: true,
  imports: [CommonModule, TranslateModule],
  template: `
    <div class="page-main">
      <header class="page-header">
        <h1 id="page-title" class="page-title">{{ titleKey | translate }}</h1>
        @if (descriptionKey) {
          <p class="page-description">{{ descriptionKey | translate }}</p>
        }
        <ng-content select="[headerActions]" />
      </header>
      <ng-content />
    </div>
  `,
  styleUrls: ['../../masters/_master-layout.css'],
})
export class AppShellComponent {
  @Input({ required: true }) titleKey!: string;
  @Input() descriptionKey?: string;
}
