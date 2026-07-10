import { Component, EventEmitter, Output } from '@angular/core';
import { CommonModule } from '@angular/common';
import { TranslateModule } from '@ngx-translate/core';
import { UndoToastService } from '../../../services/undo-toast.service';

@Component({
  selector: 'app-undo-toast',
  standalone: true,
  imports: [CommonModule, TranslateModule],
  template: `
    <div class="undo-toast" *ngIf="toastService.state().visible">
      <span>{{ toastService.state().message }}</span>
      <div class="actions">
        <button type="button" class="btn btn-white btn-sm" (click)="undo.emit()">{{ 'deletion_undo.undo_button' | translate }}</button>
        <button type="button" class="btn btn-white btn-sm" (click)="toastService.hide()">{{ 'deletion_undo.close_button' | translate }}</button>
      </div>
    </div>
  `,
  styleUrls: ['./undo-toast.component.css']
})
export class UndoToastComponent {
  @Output() undo = new EventEmitter<void>();

  constructor(public readonly toastService: UndoToastService) {}
}
