import { Component, Input } from '@angular/core';
import { CommonModule } from '@angular/common';
import { TranslateModule } from '@ngx-translate/core';

@Component({
  selector: 'app-funnel-shell',
  standalone: true,
  imports: [CommonModule, TranslateModule],
  template: `
    <header
      class="funnel-shell-header"
      [class.funnel-shell-header--hub]="variant === 'hub'"
      [class.funnel-shell-header--wizard]="variant === 'wizard'"
    >
      <h1 class="funnel-shell-title">
        @if (titleIcon) {
          <span class="title-icon" aria-hidden="true">{{ titleIcon }}</span>
        }
        <span class="title-text">{{ titleKey | translate }}</span>
      </h1>
      @if (descriptionKey) {
        <p class="funnel-shell-description muted page-intro">{{ descriptionKey | translate }}</p>
      }
      @if (variant === 'wizard') {
        <ng-content select="[wizardProgress]" />
      }
    </header>
    <div class="funnel-shell-body">
      <ng-content />
    </div>
  `,
  styleUrls: ['./funnel-shell.component.css'],
})
export class FunnelShellComponent {
  @Input() variant: 'hub' | 'wizard' = 'hub';
  @Input({ required: true }) titleKey!: string;
  @Input() descriptionKey?: string;
  @Input() titleIcon?: string;
}
