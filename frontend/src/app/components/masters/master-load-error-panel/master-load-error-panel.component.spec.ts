import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { MasterLoadErrorPanelComponent } from './master-load-error-panel.component';
import { BACKEND_WARMUP_I18N } from '../../../core/backend-warmup/backend-warmup';

describe('MasterLoadErrorPanelComponent', () => {
  let fixture: ComponentFixture<MasterLoadErrorPanelComponent>;
  let translate: TranslateService;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [MasterLoadErrorPanelComponent, TranslateModule.forRoot()],
      providers: [provideRouter([])]
    }).compileComponents();

    fixture = TestBed.createComponent(MasterLoadErrorPanelComponent);
    translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', {
      'common.api_error.not_found': 'Resource not found',
      'common.api_error.generic': 'An error occurred',
      'common.backend_warmup.database': 'Starting database…',
      'common.backend_warmup.reload': 'Reload',
      'masters.load_error.retry': 'Reload',
      'fertilizes.index.title': 'Fertilizers'
    });
    translate.use('en');

    fixture.componentRef.setInput('errorKey', 'common.api_error.not_found');
    fixture.componentRef.setInput('listLink', ['/fertilizes']);
    fixture.componentRef.setInput('backLabelKey', 'fertilizes.index.title');
  });

  it('shows translated error message without raw HTTP text', () => {
    fixture.detectChanges();

    const alert = fixture.nativeElement.querySelector('.master-load-error');
    expect(alert?.textContent).toContain('Resource not found');
    expect(alert?.textContent).not.toContain('Http failure');
    expect(alert?.textContent).not.toContain('404');
  });

  it('shows back link to list and retry button', () => {
    fixture.detectChanges();

    const backLink = fixture.nativeElement.querySelector(
      'a.master-load-error__back'
    ) as HTMLAnchorElement;
    expect(backLink?.getAttribute('href')).toBe('/fertilizes');
    expect(backLink?.textContent?.trim()).toContain('Fertilizers');
    expect(fixture.nativeElement.querySelector('.master-load-error__retry')?.textContent?.trim()).toBe(
      'Reload'
    );
  });

  it('emits retry when reload button is clicked', () => {
    fixture.detectChanges();
    const retry = vi.fn();
    fixture.componentInstance.retry.subscribe(retry);

    fixture.nativeElement.querySelector('.master-load-error__retry')?.click();

    expect(retry).toHaveBeenCalledTimes(1);
  });

  it('exposes role=alert on the error panel', () => {
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('.master-load-error[role="alert"]')).toBeTruthy();
  });

  it('shows warmup loading instead of error alert for backend warmup keys', () => {
    fixture.componentRef.setInput('errorKey', BACKEND_WARMUP_I18N.database);
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('.master-load-error')).toBeNull();
    expect(fixture.nativeElement.querySelector('.master-load-warmup')).toBeTruthy();
    expect(fixture.nativeElement.textContent).toContain('Starting database…');
    expect(fixture.nativeElement.querySelector('.master-load-warmup__retry')?.textContent?.trim()).toBe(
      'Reload'
    );
  });
});
