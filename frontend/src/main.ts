import 'zone.js';
import { bootstrapApplication } from '@angular/platform-browser';
import { appConfig } from './app/app.config';
import { App } from './app/app';
import { renderBootstrapFailureFallback } from './app/core/errors/bootstrap-failure-fallback';

bootstrapApplication(App, appConfig).catch((err) => {
  console.error(err);
  const root = document.querySelector('app-root');
  if (root instanceof HTMLElement) {
    renderBootstrapFailureFallback(root);
  }
});
