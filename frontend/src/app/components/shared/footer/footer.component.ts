import { Component } from '@angular/core';
import { RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';

@Component({
  selector: 'app-footer',
  standalone: true,
  imports: [RouterLink, TranslateModule],
  template: `
    <footer class="app-footer">
      <div class="footer-links">
        <a routerLink="/entry-schedule">{{ 'footer.entry_schedule' | translate }}</a>
        <a routerLink="/about">{{ 'footer.about' | translate }}</a>
        <a routerLink="/terms">{{ 'footer.terms' | translate }}</a>
        <a routerLink="/privacy">{{ 'footer.privacy' | translate }}</a>
        <a routerLink="/contact">{{ 'footer.contact' | translate }}</a>
      </div>
      <span>{{ 'footer.copyright' | translate }}</span>
    </footer>
  `,
  styleUrls: ['./footer.component.css']
})
export class FooterComponent {}
