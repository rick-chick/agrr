import 'zone.js';
import 'zone.js/testing';
import { afterEach, beforeAll } from 'vitest';
import { ɵresolveComponentResources as resolveComponentResources } from '@angular/core';
import { getTestBed } from '@angular/core/testing';
import {
  BrowserTestingModule,
  platformBrowserTesting
} from '@angular/platform-browser/testing';
import { clearLearnProposalApplicationProgressCache } from './app/domain/plans/learn-proposal-application-progress';

getTestBed().initTestEnvironment(
  BrowserTestingModule,
  platformBrowserTesting()
);

afterEach(() => {
  clearLearnProposalApplicationProgressCache();
});

// Vitest has no Angular build pipeline; satisfy styleUrls/templateUrl resolution without disk I/O.
beforeAll(async () => {
  await resolveComponentResources(async () => {
    return new Response('', {
      status: 200,
      headers: { 'Content-Type': 'text/css' }
    });
  });
});
