import { Routes } from '@angular/router';
import { HomeComponent } from '../components/home/home.component';
import { enLocaleResolver } from '../core/i18n/en-locale.resolver';

/** English locale mirror of public prerender routes (issue #563). */
export const localeEnRoutes: Routes = [
  {
    path: 'en',
    resolve: { _enLocale: enLocaleResolver },
    children: [
      { path: '', component: HomeComponent },
      {
        path: 'about',
        loadComponent: () =>
          import('../components/pages/about/about.component').then((m) => m.AboutComponent)
      },
      {
        path: 'contact',
        loadComponent: () =>
          import('../components/pages/contact/contact.component').then((m) => m.ContactComponent)
      },
      {
        path: 'privacy',
        loadComponent: () =>
          import('../components/pages/privacy/privacy.component').then((m) => m.PrivacyComponent)
      },
      {
        path: 'terms',
        loadComponent: () =>
          import('../components/pages/terms/terms.component').then((m) => m.TermsComponent)
      },
      {
        path: 'public-plans/new',
        loadComponent: () =>
          import('../components/public-plans/public-plan-create.component').then(
            (m) => m.PublicPlanCreateComponent
          )
      }
    ]
  }
];
