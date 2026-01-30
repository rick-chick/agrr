import {
  Component,
  Input,
  Output,
  EventEmitter,
  OnChanges,
  SimpleChanges,
} from '@angular/core';
import { RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';

const CLOSE_DELAY_MS = 200;

/**
 * 画面完結のドロップダウン（外部リクエストなし）。
 * 開閉・遅延・クリックトグルはここで完結。親は isOpen / opened / closed で相互排他だけ制御する。
 */
@Component({
  selector: 'app-nav-dropdown',
  standalone: true,
  imports: [RouterLink, TranslateModule],
  template: `
    <div
      class="nav-dropdown"
      (mouseenter)="onEnter()"
      (mouseleave)="onLeave()"
    >
      <button
        type="button"
        class="nav-dropdown-trigger"
        [attr.aria-expanded]="isOpen"
        aria-haspopup="true"
        [attr.aria-controls]="panelId"
        (click)="onToggle()"
      >
        {{ triggerLabelKey | translate }}
        <span class="dropdown-arrow" [class.is-open]="isOpen" aria-hidden="true">▼</span>
      </button>
      @if (isOpen && items.length > 0) {
        <div class="nav-dropdown-panel" [id]="panelId" role="menu">
          @for (item of items; track item.link) {
            <a
              class="nav-dropdown-link"
              [routerLink]="item.link"
              (click)="onItemClick()"
              role="menuitem"
              >{{ item.labelKey | translate }}</a>
          }
        </div>
      }
    </div>
  `,
  styleUrl: './nav-dropdown.component.css',
})
export class NavDropdownComponent implements OnChanges {
  @Input() triggerLabelKey = '';
  @Input() panelId = '';
  @Input() items: { link: string; labelKey: string }[] = [];
  @Input() isOpen = false;
  @Output() opened = new EventEmitter<void>();
  @Output() closed = new EventEmitter<void>();

  private closeTimer: ReturnType<typeof setTimeout> | null = null;

  ngOnChanges(changes: SimpleChanges): void {
    if (changes['isOpen'] && !this.isOpen && this.closeTimer !== null) {
      clearTimeout(this.closeTimer);
      this.closeTimer = null;
    }
  }

  onEnter(): void {
    if (this.closeTimer !== null) {
      clearTimeout(this.closeTimer);
      this.closeTimer = null;
    }
    this.opened.emit();
  }

  onLeave(): void {
    this.closeTimer = setTimeout(() => {
      this.closed.emit();
      this.closeTimer = null;
    }, CLOSE_DELAY_MS);
  }

  onToggle(): void {
    if (this.isOpen) {
      this.closed.emit();
    } else {
      if (this.closeTimer !== null) {
        clearTimeout(this.closeTimer);
        this.closeTimer = null;
      }
      this.opened.emit();
    }
  }

  onItemClick(): void {
    this.closed.emit();
  }
}
