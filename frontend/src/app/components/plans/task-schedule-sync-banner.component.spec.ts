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
        'plans.task_schedules.sync_never': 'Not generated yet.',
        'plans.task_schedules.sync_failed': 'Generation failed.',
        'plans.task_schedules.sync_generating': 'Generating...',
        'plans.task_schedules.sync_stale': 'Schedules are stale.',
        'plans.task_schedules.sync_retry': 'Regenerate',
        'plans.task_schedules.sync_errors.agrr_unavailable':
          'Could not reach the AGRR processing service.',
        'plans.task_schedules.sync_errors.generic': 'Task schedules could not be created.',
        'plans.task_schedules.sync_errors.generic_single':
          'Registration for "{{cropName}}" is incomplete, so task schedules could not be created.',
        'plans.task_schedules.sync_errors.generic_multi':
          'Registration for the crops below is incomplete, so task schedules could not be created. Complete setup in the registration wizard.',
        'plans.task_schedules.sync_errors.generic_no_plan_crops':
          'No crops were found on this plan. Check fields and crops on the plan.',
        'plans.task_schedules.sync_errors.generic_named': 'Check settings for "{{cropName}}".',
        'plans.task_schedules.sync_errors.crop_wizard_link':
          'Open registration wizard for "{{cropName}}"',
        'plans.task_schedules.sync_wizard_cta_hint': 'Open registration wizard',
        'plans.task_schedules.sync_errors.generic_plan_link': 'Open plan fields and crops',
        'plans.task_schedules.sync_errors.missing_general_templates':
          'General work blueprints are missing.',
        'plans.task_schedules.sync_errors.missing_general_templates_named':
          'General work blueprints for "{{cropName}}" are missing.',
        'plans.task_schedules.sync_errors.missing_general_templates_link':
          'Register general work blueprints from crop list',
        'plans.task_schedules.sync_errors.missing_crop_blueprints':
          'Blueprints are missing.',
        'plans.task_schedules.sync_errors.missing_crop_blueprints_named':
          'Blueprints for "{{cropName}}" are missing.',
        'plans.task_schedules.sync_errors.missing_crop_templates':
          'Templates are missing.',
        'plans.task_schedules.sync_errors.missing_crop_templates_link':
          'Register task templates from crop list',
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

  it('hides retry and links to crop detail when blueprints are missing', () => {
    component.syncState = 'failed';
    component.syncError = 'plans.task_schedules.sync_errors.missing_crop_blueprints';
    component.syncErrorCropId = 42;
    component.planId = 7;
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('button')).toBeNull();
    const link = fixture.nativeElement.querySelector('a.task-schedule-sync-banner__wizard-cta');
    expect(link).toBeTruthy();
    expect(link.getAttribute('href')).toContain('/crops/42');
    expect(link.getAttribute('href')).toContain('fromPlan=7');
    expect(link.getAttribute('href')).toContain('blueprints-heading');
    expect(link.textContent).toContain('Open registration wizard for "#42"');
  });

  it('shows crop name in blueprint deficiency message and link', () => {
    component.syncState = 'failed';
    component.syncError = 'plans.task_schedules.sync_errors.missing_crop_blueprints';
    component.syncErrorCropId = 42;
    component.cropNames = { 42: 'Tomato' };
    fixture.detectChanges();

    const text = fixture.nativeElement.textContent ?? '';
    expect(text).toContain('Blueprints for "Tomato" are missing.');
    expect(text).toContain('Open registration wizard for "Tomato"');
    expect(fixture.nativeElement.querySelector('button')).toBeNull();
  });

  it('prefers syncErrorCropId over multiple cropIds for remediation link', () => {
    component.syncState = 'failed';
    component.syncError = 'plans.task_schedules.sync_errors.missing_crop_blueprints';
    component.syncErrorCropId = 15;
    component.cropIds = [42, 99];
    fixture.detectChanges();

    const link = fixture.nativeElement.querySelector('a.task-schedule-sync-banner__wizard-cta');
    expect(link.getAttribute('href')).toContain('/crops/15');
  });

  it('links to crop list when templates are missing without a target crop', () => {
    component.syncState = 'failed';
    component.syncError = 'plans.task_schedules.sync_errors.missing_crop_templates';
    component.cropIds = [];
    fixture.detectChanges();

    const link = fixture.nativeElement.querySelector('a.task-schedule-sync-banner__wizard-cta');
    expect(link).toBeTruthy();
    expect(link.getAttribute('href')).toContain('/crops');
    expect(link.getAttribute('href')).toContain('task-templates-heading');
    expect(link.textContent).toContain('Register task templates from crop list');
  });

  it('opens wizard for a single known crop on template deficiency', () => {
    component.syncState = 'failed';
    component.syncError = 'plans.task_schedules.sync_errors.missing_crop_templates';
    component.cropIds = [42];
    fixture.detectChanges();

    const link = fixture.nativeElement.querySelector('a.task-schedule-sync-banner__link--primary');
    expect(link.getAttribute('href')).toContain('/crops/42');
    expect(link.getAttribute('href')).toContain('task-templates-heading');
    expect(link.textContent).toContain('Open registration wizard for "#42"');
  });

  it('shows generic single-crop message and wizard link', () => {
    component.syncState = 'failed';
    component.syncError = 'plans.task_schedules.sync_errors.generic';
    component.cropIds = [42];
    component.cropNames = { 42: 'Tomato' };
    component.planId = 7;
    fixture.detectChanges();

    const text = fixture.nativeElement.textContent ?? '';
    expect(text).not.toContain('Generation failed.');
    expect(text).toContain('Registration for "Tomato" is incomplete');
    const link = fixture.nativeElement.querySelector('a.task-schedule-sync-banner__crop-link');
    expect(link?.getAttribute('href')).toContain('/crops/42');
    expect(link?.getAttribute('href')).toContain('task-templates-heading');
    expect(link?.textContent).toContain('Tomato');
    expect(link?.textContent).toContain('Open registration wizard');
    expect(fixture.nativeElement.querySelector('button')).toBeNull();
    expect(fixture.nativeElement.textContent).not.toContain('Open crop list');
  });

  it('lists each plan crop when generic error has multiple crops', () => {
    component.syncState = 'failed';
    component.syncError = 'plans.task_schedules.sync_errors.generic';
    component.cropIds = [42, 99];
    component.cropNames = { 42: 'Tomato', 99: 'Lettuce' };
    component.planId = 7;
    fixture.detectChanges();

    const text = fixture.nativeElement.textContent ?? '';
    expect(text).toContain('Registration for the crops below is incomplete');
    expect(text).toContain('Tomato');
    expect(text).toContain('Lettuce');
    const links = fixture.nativeElement.querySelectorAll(
      'a.task-schedule-sync-banner__crop-link'
    );
    expect(links.length).toBe(2);
    expect(links[0].getAttribute('href')).toContain('/crops/42');
    expect(links[0].getAttribute('href')).toContain('task-templates-heading');
    expect(links[1].getAttribute('href')).toContain('/crops/99');
    expect(links[1].getAttribute('href')).toContain('task-templates-heading');
    expect(
      fixture.nativeElement.querySelector('.task-schedule-sync-banner__link--primary')
    ).toBeNull();
    expect(fixture.nativeElement.querySelector('button')).toBeNull();
    expect(text).not.toContain('Open crop list');
  });

  it('links to plan when generic error has no crop context', () => {
    component.syncState = 'failed';
    component.syncError = 'plans.task_schedules.sync_errors.generic';
    component.cropIds = [];
    component.planId = 7;
    fixture.detectChanges();

    const text = fixture.nativeElement.textContent ?? '';
    expect(text).toContain('No crops were found on this plan');
    const link = fixture.nativeElement.querySelector('a.task-schedule-sync-banner__link--primary');
    expect(link).toBeTruthy();
    expect(link.getAttribute('href')).toContain('/plans/7');
    expect(link.textContent).toContain('Open plan fields and crops');
    expect(text).not.toContain('Open crop list');
    expect(fixture.nativeElement.querySelector('button')).toBeNull();
  });

  it('shows crop settings link when only sync error crop id is known', () => {
    component.syncState = 'failed';
    component.syncError = 'plans.task_schedules.sync_errors.generic';
    component.syncErrorCropId = 42;
    component.cropNames = {};
    fixture.detectChanges();

    const link = fixture.nativeElement.querySelector('a.task-schedule-sync-banner__crop-link');
    expect(link.getAttribute('href')).toContain('/crops/42');
    expect(fixture.nativeElement.textContent).not.toContain('Open crop list');
  });

  it('shows missing general templates named message and remediation links', () => {
    component.syncState = 'failed';
    component.syncError = 'plans.task_schedules.sync_errors.missing_general_templates';
    component.syncErrorCropId = 42;
    component.cropNames = { 42: 'Tomato' };
    fixture.detectChanges();

    const text = fixture.nativeElement.textContent ?? '';
    expect(text).toContain('General work blueprints for "Tomato" are missing.');
    const link = fixture.nativeElement.querySelector('a.task-schedule-sync-banner__wizard-cta');
    expect(link.getAttribute('href')).toContain('/crops/42');
    expect(link.getAttribute('href')).toContain('blueprints-heading');
    expect(link.textContent).toContain('Open registration wizard for "Tomato"');
    expect(fixture.nativeElement.querySelector('button')).toBeNull();
  });

  it('lists wizard links for multiple crops when blueprints are missing', () => {
    component.syncState = 'failed';
    component.syncError = 'plans.task_schedules.sync_errors.missing_crop_blueprints';
    component.cropIds = [42, 99];
    component.cropNames = { 42: 'Tomato', 99: 'Lettuce' };
    component.planId = 7;
    fixture.detectChanges();

    const links = fixture.nativeElement.querySelectorAll('a.task-schedule-sync-banner__crop-link');
    expect(links.length).toBe(2);
    expect(links[0].getAttribute('href')).toContain('/crops/42');
    expect(links[0].getAttribute('href')).toContain('blueprints-heading');
    expect(links[1].getAttribute('href')).toContain('/crops/99');
    expect(fixture.nativeElement.querySelector('button')).toBeNull();
  });
});
