import { Component, inject } from '@angular/core';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { applyAppLang, type AppLang } from '../../../core/app-locale';

const APP_LANGS: AppLang[] = ['ja', 'en', 'in'];

@Component({
  selector: 'app-language-switcher',
  standalone: true,
  imports: [TranslateModule],
  template: `
    <div class="language-switcher" (keydown.escape)="close()">
      <button
        type="button"
        class="language-switcher-trigger"
        [attr.aria-expanded]="isOpen"
        aria-haspopup="listbox"
        [attr.aria-label]="'nav.language' | translate"
        aria-controls="language-switcher-panel"
        (click)="toggle()"
      >
        {{ 'nav.language' | translate }}
        <span class="language-switcher-arrow" [class.is-open]="isOpen" aria-hidden="true">▼</span>
      </button>
      @if (isOpen) {
        <div
          id="language-switcher-panel"
          class="language-switcher-panel"
          role="listbox"
          [attr.aria-label]="'nav.language' | translate"
        >
          @for (lang of languages; track lang) {
            <button
              type="button"
              class="language-switcher-option"
              role="option"
              [attr.data-lang]="lang"
              [attr.aria-current]="isSelected(lang) ? 'true' : null"
              [class.is-selected]="isSelected(lang)"
              (click)="selectLang(lang)"
            >
              {{ labelKey(lang) | translate }}
            </button>
          }
        </div>
      }
    </div>
  `,
  styleUrls: ['./language-switcher.component.css'],
})
export class LanguageSwitcherComponent {
  private readonly translate = inject(TranslateService);

  readonly languages = APP_LANGS;
  isOpen = false;

  get currentLang(): AppLang {
    const lang = this.translate.currentLang || this.translate.defaultLang || 'ja';
    return lang === 'ja' || lang === 'en' || lang === 'in' ? lang : 'ja';
  }

  labelKey(lang: AppLang): string {
    return `nav.lang_${lang}`;
  }

  isSelected(lang: AppLang): boolean {
    return this.currentLang === lang;
  }

  toggle(): void {
    this.isOpen = !this.isOpen;
  }

  close(): void {
    this.isOpen = false;
  }

  selectLang(lang: AppLang): void {
    applyAppLang(this.translate, lang);
    this.close();
  }
}
