import { Component, EventEmitter, Output } from '@angular/core';
import { CommonModule } from '@angular/common';
import { UndoToastService } from '../../../services/undo-toast.service';

@Component({
  selector: 'app-undo-toast',
  standalone: true,
  imports: [CommonModule],
  template: `
    <div class="undo-toast" *ngIf="toastService.state().visible">
      <span>{{ toastService.state().message }}</span>
      <div class="actions">
        <button type="button" (click)="undo.emit()">Undo</button>
        <button type="button" (click)="toastService.hide()">Close</button>
      </div>
    </div>
  `,
  styleUrl: './undo-toast.component.css'
})
export class UndoToastComponent {
  @Output() undo = new EventEmitter<void>();

  constructor(public readonly toastService: UndoToastService) {}
}
