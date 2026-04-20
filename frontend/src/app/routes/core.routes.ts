import { Routes } from '@angular/router';
import { authGuard } from '../guards/auth.guard';
import { HomeComponent } from '../components/home/home.component';
import { LoginComponent } from '../components/auth/login/login.component';

export const coreRoutes: Routes = [
  { path: '', component: HomeComponent },
  { path: 'login', component: LoginComponent },
  { path: 'auth/login', redirectTo: 'login', pathMatch: 'full' },
  { path: 'dashboard', component: HomeComponent, canActivate: [authGuard] }
];
