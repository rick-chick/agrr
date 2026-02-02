import { Component } from '@angular/core';
import { RouterLink } from '@angular/router';

@Component({
  selector: 'app-footer',
  standalone: true,
  imports: [RouterLink],
  template: `
    <footer class="app-footer">
      <div class="footer-links">
        <a routerLink="/about">AGRRについて</a>
        <a routerLink="/terms">利用規約</a>
        <a routerLink="/privacy">プライバシーポリシー</a>
        <a routerLink="/contact">お問い合わせ</a>
      </div>
      <span>AGRR © 2026</span>
    </footer>
  `,
  styleUrls: ['./footer.component.css']
})
export class FooterComponent {}
