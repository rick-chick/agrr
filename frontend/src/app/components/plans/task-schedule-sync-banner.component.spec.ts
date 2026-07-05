import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { describe, expect, it, vi } from 'vitest';
import { TaskScheduleSyncBannerComponent } from './task-schedule-sync-banner.component';

describe('TaskScheduleSyncBannerComponent', () => {
  let fixture: ComponentFixture<TaskScheduleSyncBannerComponent>;
  let component: TaskScheduleSyncBannerComponent;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [TaskScheduleSyncBannerComponent, TranslateModule.forRoot()],
      providers: [provideRouter([])]
    }).compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setDefaultLang('en');
    translate.use('en');
    translate.setTranslation(
      'en',
      {
        'plans.task_schedules.sync_failed': 'Generation failed.',
        'plans.task_schedules.sync_generating': 'Generating...',
        'plans.task_schedules.sync_stale': 'Schedules are stale.',
        'plans.task_schedules.sync_retry': 'Regenerate',
        'plans.task_schedules.sync_errors.agrr_unavailable':
          'Could not reach the AGRR processing service.',
        'common.loading': 'Loading...'
      },
      true
    );

    fixture = TestBed.createComponent(TaskScheduleSyncBannerComponent);
    component = fixture.componentInstance;
  });

  it('hides banner when sync state is ready', () => {
    component.syncState = 'ready';
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('.task-schedule-sync-banner')).toBeNull();
  });

  it('shows retry for transient failed state and emits retry', () => {
    component.syncState = 'failed';
    component.syncError = 'plans.task_schedules.sync_errors.agrr_unavailable';
    fixture.detectChanges();

    const retrySpy = vi.fn();
    component.retry.subscribe(retrySpy);
    fixture.nativeElement.querySelector('button')?.click();
    expect(retrySpy).toHaveBeenCalled();
    expect(fixture.nativeElement.textContent).not.toContain('Generation failed.');
    expect(fixture.nativeElement.textContent).toContain(
      'Could not reach the AGRR processing service.'
    );
  });

  it('hides retry while generating', () => {
    component.syncState = 'generating';
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('button')).toBeNull();
    expect(fixture.nativeElement.textContent).toContain('Generating...');
  });

  it('hides retry for stale state', () => {
    component.syncState = 'stale';
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('button')).toBeNull();
    expect(fixture.nativeElement.textContent).toContain('Schedules are stale.');
  });
});
