import 'zone.js';
import { bootstrapApplication } from '@angular/platform-browser';
import { appConfig } from './app/app.config';
import { App } from './app/app';
import { renderFatalErrorFallback } from './app/core/errors/render-fatal-error-fallback';

bootstrapApplication(App, appConfig).catch((err) => {
  console.error(err);
  const host = document.querySelector('app-root');
  if (host instanceof HTMLElement) {
    renderFatalErrorFallback(host, { kind: 'bootstrap' });
  }
});
