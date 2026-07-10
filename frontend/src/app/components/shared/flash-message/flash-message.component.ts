import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { TranslateModule } from '@ngx-translate/core';
import { FlashMessageService } from '../../../services/flash-message.service';

@Component({
  selector: 'app-flash-message',
  standalone: true,
  imports: [CommonModule, TranslateModule],
  template: `
    <div class="flash-container" aria-live="polite">
      <div
        class="flash-message"
        [class]="message.type"
        *ngFor="let message of flashService.messages()"
        role="status"
      >
        <span>{{ message.text }}</span>
        <button
          type="button"
          class="btn-link"
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
