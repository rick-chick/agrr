import { Routes } from '@angular/router';
import { authGuard } from '../guards/auth.guard';
import { HomeComponent } from '../components/home/home.component';
import { LoginComponent } from '../components/auth/login/login.component';
import { ApiKeysComponent } from '../components/settings/api-keys/api-keys.component';
import { AccountComponent } from '../components/settings/account/account.component';

export const coreRoutes: Routes = [
  { path: '', component: HomeComponent },
  { path: 'login', component: LoginComponent },
  { path: 'auth/login', redirectTo: 'login', pathMatch: 'full' },
  { path: 'dashboard', redirectTo: '', pathMatch: 'full' },
  { path: 'api-keys', component: ApiKeysComponent, canActivate: [authGuard] },
  { path: 'account', component: AccountComponent, canActivate: [authGuard] }
];
