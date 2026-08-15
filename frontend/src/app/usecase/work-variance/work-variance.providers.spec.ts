import { InjectionToken } from '@angular/core';
import { describe, expect, it } from 'vitest';
import { WORK_VARIANCE_INIT_OUTPUT_PORT } from './work-variance-init.output-port';

describe('WORK_VARIANCE_INIT_OUTPUT_PORT', () => {
  it('uses InjectionToken so Angular can register component providers', () => {
    expect(WORK_VARIANCE_INIT_OUTPUT_PORT).toBeInstanceOf(InjectionToken);
  });
});
