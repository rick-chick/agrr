import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FlashMessageService } from '../../../services/flash-message.service';

@Component({
  selector: 'app-flash-message',
  standalone: true,
  imports: [CommonModule],
  template: `
    <div class="flash-container" aria-live="polite">
      <div
        class="flash-message"
        [class]="message.type"
        *ngFor="let message of flashService.messages()"
      >
        <span>{{ message.text }}</span>
        <button type="button" (click)="flashService.remove(message.id)">×</button>
      </div>
    </div>
  `,
  styleUrl: './flash-message.component.css'
})
export class FlashMessageComponent {
  constructor(public readonly flashService: FlashMessageService) {}
}
