import { ComponentFixture, TestBed } from '@angular/core/testing';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { describe, expect, it, beforeEach } from 'vitest';
import { BACKEND_WARMUP_I18N } from '../../../core/backend-warmup/backend-warmup';
import { BackendWarmupLoadingComponent } from './backend-warmup-loading.component';

describe('BackendWarmupLoadingComponent', () => {
  let fixture: ComponentFixture<BackendWarmupLoadingComponent>;
  let translate: TranslateService;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [BackendWarmupLoadingComponent, TranslateModule.forRoot()]
    }).compileComponents();

    translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', {
      common: {
        backend_warmup: {
          database: 'Starting database…',
          compute_engine: 'Starting compute engine…'
        }
      }
    });
    translate.use('en');

    fixture = TestBed.createComponent(BackendWarmupLoadingComponent);
  });

  it('renders database warmup message with spinner by default', () => {
    fixture.detectChanges();

    const status = fixture.nativeElement.querySelector('[role="status"]');
    expect(status).toBeTruthy();
    expect(status.querySelector('.backend-warmup-loading__spinner')).toBeTruthy();
    expect(status.textContent).toContain('Starting database…');
  });

  it('renders custom warmup message key', () => {
    fixture.componentRef.setInput('messageKey', BACKEND_WARMUP_I18N.computeEngine);
    fixture.detectChanges();

    expect(fixture.nativeElement.textContent).toContain('Starting compute engine…');
  });
});
