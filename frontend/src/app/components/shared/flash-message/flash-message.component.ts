import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { FlashMessageService } from '../../../services/flash-message.service';

@Component({
  selector: 'app-flash-message',
  standalone: true,
  imports: [CommonModule, TranslateModule, RouterLink],
  template: `
    <div class="flash-container" aria-live="polite">
      <div
        class="flash-message"
        [class]="message.type"
        *ngFor="let message of flashService.messages()"
        role="status"
      >
        <div class="flash-message__content">
          <span>{{ message.text }}</span>
          @if (message.action) {
            <a
              class="flash-message__action"
              [routerLink]="message.action.routerLink"
              [queryParams]="message.action.queryParams"
              (click)="flashService.remove(message.id)"
            >
              {{ message.action.labelKey | translate }}
            </a>
          }
        </div>
        <button
          type="button"
          [attr.aria-label]="'common.close' | translate"
          (click)="flashService.remove(message.id)"
        >
          {{ 'common.close' | translate }}
        </button>
      </div>
    </div>
  `,
  styleUrls: ['./flash-message.component.css']
})
export class FlashMessageComponent {
  constructor(public readonly flashService: FlashMessageService) {}
}
