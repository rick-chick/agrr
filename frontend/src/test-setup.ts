import 'zone.js';
import 'zone.js/testing';
import { beforeAll } from 'vitest';
import { ɵresolveComponentResources as resolveComponentResources } from '@angular/core';
import { getTestBed } from '@angular/core/testing';
import {
  BrowserTestingModule,
  platformBrowserTesting
} from '@angular/platform-browser/testing';

getTestBed().initTestEnvironment(
  BrowserTestingModule,
  platformBrowserTesting()
);

// Vitest has no Angular build pipeline; satisfy styleUrls/templateUrl resolution without disk I/O.
beforeAll(async () => {
  await resolveComponentResources(async () => {
    return new Response('', {
      status: 200,
      headers: { 'Content-Type': 'text/css' }
    });
  });
});
