import { TestBed } from '@angular/core/testing';
import { Router } from '@angular/router';
import { of } from 'rxjs';
import { describe, expect, it, vi } from 'vitest';
import { onboardingGuard } from './onboarding.guard';
import { ApiService } from '../services/api.service';

describe('onboardingGuard', () => {
  it('allows access when user has no plans', async () => {
    TestBed.configureTestingModule({
      providers: [
        {
          provide: ApiService,
          useValue: { get: vi.fn(() => of([])) }
        },
        {
          provide: Router,
          useValue: { createUrlTree: vi.fn(() => '/plans') }
        }
      ]
    });

    const result = await TestBed.runInInjectionContext(() => onboardingGuard({} as never, {} as never));
    expect(result).toBe(true);
  });

  it('redirects to plans when user already has a saved plan', async () => {
    const urlTree = { toString: () => '/plans' };
    const createUrlTree = vi.fn(() => urlTree);
    TestBed.configureTestingModule({
      providers: [
        {
          provide: ApiService,
          useValue: { get: vi.fn(() => of([{ id: 1, name: 'Plan', farm_id: 1 }])) }
        },
        {
          provide: Router,
          useValue: { createUrlTree }
        }
      ]
    });

    const result = await TestBed.runInInjectionContext(() => onboardingGuard({} as never, {} as never));
    expect(createUrlTree).toHaveBeenCalledWith(['/plans']);
    expect(result).toBe(urlTree);
  });
});
