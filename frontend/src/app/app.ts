import { Component, OnInit, inject } from '@angular/core';
import { Router } from '@angular/router';
import { RouterOutlet } from '@angular/router';
import { TranslateService } from '@ngx-translate/core';
import { NavbarComponent } from './components/shared/navbar/navbar.component';
import { FooterComponent } from './components/shared/footer/footer.component';
import { FlashMessageComponent } from './components/shared/flash-message/flash-message.component';
import { UndoToastComponent } from './components/shared/undo-toast/undo-toast.component';
import { AuthService } from './services/auth.service';
import { UndoToastService } from './services/undo-toast.service';
import { getApiBaseUrl } from './core/api-base-url';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [RouterOutlet, NavbarComponent, FooterComponent, FlashMessageComponent, UndoToastComponent],
  templateUrl: './app.html',
  styleUrls: ['./app.css']
})
export class App implements OnInit {
  private readonly translate = inject(TranslateService);
  protected readonly authService = inject(AuthService);
  private readonly router = inject(Router);
  private readonly undoToastService = inject(UndoToastService);
  protected readonly apiBaseUrl = getApiBaseUrl();

  performUndo(): void {
    this.undoToastService.performUndo();
  }

  logout(): void {
    this.authService.logout().subscribe({
      next: () => {
        this.router.navigate(['/login']);
      },
      error: () => {
        this.router.navigate(['/login']);
      }
    });
  }

  ngOnInit(): void {
    this.translate.addLangs(['ja', 'en']);
    this.translate.setDefaultLang('ja');
    this.translate.use('ja');
    this.authService.loadCurrentUser().subscribe();
  }
}
