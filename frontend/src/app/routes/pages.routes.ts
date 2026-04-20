import { Routes } from '@angular/router';

export const pagesRoutes: Routes = [
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
    path: '**',
    loadComponent: () =>
      import('../components/pages/not-found/not-found.component').then((m) => m.NotFoundComponent)
  }
];
