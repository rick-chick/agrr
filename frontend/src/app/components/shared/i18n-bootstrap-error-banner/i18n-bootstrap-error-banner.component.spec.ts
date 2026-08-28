import { ComponentFixture, TestBed } from '@angular/core/testing';
import { describe, expect, it, vi } from 'vitest';
import { TranslateModule } from '@ngx-translate/core';
import { signal } from '@angular/core';
import { I18nBootstrapErrorBannerComponent } from './i18n-bootstrap-error-banner.component';
import { I18nBootstrapStateService } from '../../../core/i18n/i18n-bootstrap-state.service';

describe('I18nBootstrapErrorBannerComponent', () => {
  let fixture: ComponentFixture<I18nBootstrapErrorBannerComponent>;
  let loadFailed: ReturnType<typeof signal<boolean>>;
  let retrying: ReturnType<typeof signal<boolean>>;
  let retrySpy: ReturnType<typeof vi.fn>;

  beforeEach(async () => {
    loadFailed = signal(false);
    retrying = signal(false);
    retrySpy = vi.fn().mockResolvedValue(undefined);

    await TestBed.configureTestingModule({
      imports: [I18nBootstrapErrorBannerComponent, TranslateModule.forRoot()],
      providers: [
        {
          provide: I18nBootstrapStateService,
          useValue: {
            loadFailed,
            retrying,
            retry: retrySpy
          }
        }
      ]
    }).compileComponents();

    fixture = TestBed.createComponent(I18nBootstrapErrorBannerComponent);
  });

  it('renders nothing when bootstrap succeeded', () => {
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('.i18n-bootstrap-error')).toBeNull();
  });

  it('shows load failure message and retry button when bootstrap failed', () => {
    loadFailed.set(true);
    fixture.detectChanges();

    const alert = fixture.nativeElement.querySelector('.i18n-bootstrap-error');
    expect(alert).toBeTruthy();
    expect(alert.textContent).toContain('common.i18n.bootstrap.load_failed');
    expect(fixture.nativeElement.querySelector('.i18n-bootstrap-error__retry')).toBeTruthy();
  });

  it('calls retry on button click', () => {
    loadFailed.set(true);
    fixture.detectChanges();

    fixture.nativeElement.querySelector('.i18n-bootstrap-error__retry').click();
    expect(retrySpy).toHaveBeenCalled();
  });
});
