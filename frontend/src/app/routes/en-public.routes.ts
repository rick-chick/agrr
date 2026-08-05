import { Routes } from '@angular/router';
import { HomeComponent } from '../components/home/home.component';
import { prerenderEnLocaleResolver } from '../core/i18n/prerender-locale.resolver';

/** English locale mirrors of public prerender routes (`/en`, `/en/about`, …). */
export const enPublicRoutes: Routes = [
  {
    path: 'en',
    resolve: { prerenderLocale: prerenderEnLocaleResolver },
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
      },
      {
        path: 'entry-schedule',
        loadComponent: () =>
          import('../components/entry-schedule/entry-schedule-list.component').then(
            (m) => m.EntryScheduleListComponent
          )
      }
    ]
  }
];
