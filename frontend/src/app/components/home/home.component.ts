import { Component } from '@angular/core';
import { TranslateModule } from '@ngx-translate/core';
import { AuthService } from '../../services/auth.service';

@Component({
  selector: 'app-home',
  standalone: true,
  imports: [TranslateModule],
  template: `
    <section class="welcome">
      @if (authService.user()) {
        <h1>{{ 'home.welcome' | translate: { name: authService.user()!.name ?? ('home.user_fallback' | translate) } }}</h1>
        <p>{{ 'home.welcomeMessage' | translate }}</p>
      } @else if (authService.loading()) {
        <h1>{{ 'status.checking' | translate }}</h1>
        <p>{{ 'home.loginPrompt' | translate }}</p>
      } @else {
        <h1>{{ 'home.loginRequired' | translate }}</h1>
        <p>{{ 'home.loginPrompt' | translate }}</p>
      }
    </section>
  `,
  styleUrls: ['./home.component.css']
})
export class HomeComponent {
  constructor(public readonly authService: AuthService) {}
}
