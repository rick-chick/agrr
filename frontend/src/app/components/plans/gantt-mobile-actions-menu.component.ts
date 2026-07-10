import {
  Component,
  EventEmitter,
  HostListener,
  Input,
  Output
} from '@angular/core';
import { CommonModule } from '@angular/common';
import { TranslateModule } from '@ngx-translate/core';
import { GANTT_I18N_KEYS } from '../../core/i18n/gantt-locale.keys';

/**
 * ガント・アクションバーのモバイル用「その他」メニュー（画面完結 UI）。
 * 開閉・外側クリック・Escape はここで完結。圃場フォーム／凡例の表示状態は親が持つ。
 */
@Component({
  selector: 'app-gantt-mobile-actions-menu',
  standalone: true,
  imports: [CommonModule, TranslateModule],
  template: `
    <div class="gantt-mobile-actions-menu">
      <button
        class="btn btn-secondary btn-sm gantt-mobile-actions-menu__trigger"
        type="button"
        (click)="toggleMenu()"
        [class.active]="menuOpen || fieldFormVisible || fieldLegendOpen"
        [attr.aria-expanded]="menuOpen"
        [attr.aria-controls]="panelId"
        aria-haspopup="menu"
        [attr.aria-label]="ganttI18n.mobile.moreActions | translate">
        <svg class="gantt-btn__icon" viewBox="0 0 24 24" aria-hidden="true">
          <path
            fill="currentColor"
            d="M12 8c1.1 0 2-.9 2-2s-.9-2-2-2-2 .9-2 2 .9 2 2 2zm0 2c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2zm0 6c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2z" />
        </svg>
      </button>
      @if (menuOpen) {
        <div class="gantt-mobile-actions-menu__panel" [id]="panelId" role="menu">
          <button
            class="btn btn-secondary gantt-mobile-actions-menu__item"
            type="button"
            role="menuitem"
            (click)="onAddFieldClick()"
            [class.active]="fieldFormVisible">
            @if (!fieldFormVisible) {
              <span>{{ ganttI18n.js.addFieldButton | translate }}</span>
            } @else {
              <span>{{ ganttI18n.js.cropPaletteCancel | translate }}</span>
            }
          </button>
          <button
            class="btn btn-secondary gantt-mobile-actions-menu__item"
            type="button"
            role="menuitem"
            (click)="onFieldLegendClick()"
            [class.active]="fieldLegendOpen">
            @if (!fieldLegendOpen) {
              <span>{{ ganttI18n.mobile.fieldLegendButton | translate }}</span>
            } @else {
              <span>{{ ganttI18n.js.cropPaletteCancel | translate }}</span>
            }
          </button>
        </div>
      }
    </div>
  `,
  styleUrls: ['./gantt-mobile-actions-menu.component.css']
})
export class GanttMobileActionsMenuComponent {
  protected readonly ganttI18n = GANTT_I18N_KEYS;
  readonly panelId = 'gantt-mobile-actions-menu-panel';

  @Input() fieldFormVisible = false;
  @Input() fieldLegendOpen = false;

  @Output() addFieldToggle = new EventEmitter<void>();
  @Output() fieldLegendToggle = new EventEmitter<void>();

  menuOpen = false;

  toggleMenu(): void {
    this.menuOpen = !this.menuOpen;
  }

  closeMenu(): void {
    this.menuOpen = false;
  }

  onAddFieldClick(): void {
    this.closeMenu();
    this.addFieldToggle.emit();
  }

  onFieldLegendClick(): void {
    this.closeMenu();
    this.fieldLegendToggle.emit();
  }

  @HostListener('document:click', ['$event'])
  onDocumentClick(event: MouseEvent): void {
    this.dismissIfOutside(event.target);
  }

  @HostListener('document:keydown', ['$event'])
  onDocumentKeydown(event: KeyboardEvent): void {
    if (!this.menuOpen || event.key !== 'Escape') {
      return;
    }
    event.preventDefault();
    this.closeMenu();
  }

  private dismissIfOutside(target: EventTarget | null): void {
    if (!this.menuOpen) {
      return;
    }
    if (target instanceof Element && target.closest('.gantt-mobile-actions-menu')) {
      return;
    }
    this.closeMenu();
  }
}
