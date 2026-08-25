import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute, provideRouter, Router } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { of } from 'rxjs';
import { vi } from 'vitest';
import { EntryScheduleDetailComponent } from './entry-schedule-detail.component';
import { ENTRY_SCHEDULE_GATEWAY } from '../../usecase/entry-schedule/entry-schedule-gateway';
import { PublicPlanStore } from '../../services/public-plans/public-plan-store.service';
import { AuthService } from '../../services/auth.service';
import type { CurrentUser } from '../../services/api.service';

describe('EntryScheduleDetailComponent', () => {
  let fixture: ComponentFixture<EntryScheduleDetailComponent>;
  let translate: TranslateService;
  let authUser: CurrentUser | null = null;

  beforeEach(async () => {
    authUser = null;
    await TestBed.configureTestingModule({
      imports: [EntryScheduleDetailComponent, TranslateModule.forRoot()],
      providers: [
        provideRouter([]),
        {
          provide: AuthService,
          useValue: {
            user: () => authUser
          }
        },
        {
          provide: ActivatedRoute,
          useValue: {
            snapshot: {
              paramMap: { get: vi.fn().mockReturnValue('7') },
              queryParamMap: { get: vi.fn().mockReturnValue('3') }
            },
            paramMap: of({ get: () => '7' }),
            queryParamMap: of({ get: () => '3' })
          }
        },
        {
          provide: ENTRY_SCHEDULE_GATEWAY,
          useValue: {
            getEntryScheduleCrop: vi.fn(() =>
              of({
                crop: {
                  name: 'Tomato',
                  entry_disclaimer: 'Disclaimer',
                  reason_summary: 'Summary',
                  labels: { sowing: 'Sow', transplanting: 'Transplant' },
                  sowing_windows: [],
                  transplant_windows: [],
                  crop_stages: []
                },
                prediction: {}
              })
            )
          }
        }
      ]
    }).compileComponents();

    fixture = TestBed.createComponent(EntryScheduleDetailComponent);
    translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', {
      'entrySchedule.title': 'Entry schedule',
      'entrySchedule.detailTitle': 'Crop schedule'
    });
    translate.setDefaultLang('en');
    translate.use('en');
  });

  it('renders crop name as the single page h1 when data is loaded', async () => {
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();

    const headings = fixture.nativeElement.querySelectorAll('h1');
    expect(headings.length).toBe(1);
    expect(headings[0].textContent?.trim()).toContain('Tomato');
    expect(fixture.nativeElement.querySelector('h2#crop-name-heading')).toBeNull();
  });

  it('renders breadcrumb with list link and crop name instead of inline back link', async () => {
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();

    const backLink = fixture.nativeElement.querySelector(
      'a.master-context-header__back'
    ) as HTMLAnchorElement;
    expect(backLink).toBeTruthy();
    expect(backLink.getAttribute('href')).toBe('/entry-schedule');
    expect(backLink.textContent?.trim()).toBe('Entry schedule');

    const current = fixture.nativeElement.querySelector('[aria-current="page"]');
    expect(current?.textContent?.trim()).toBe('Tomato');
    expect(fixture.nativeElement.querySelector('a.link-inline')).toBeNull();
    expect(fixture.nativeElement.textContent).not.toContain('Back to list');
  });

  it('renders growth stages without duplicate list numbering', async () => {
    const gateway = TestBed.inject(ENTRY_SCHEDULE_GATEWAY);
    vi.mocked(gateway.getEntryScheduleCrop).mockReturnValue(
      of({
        farm: { id: 3, name: 'Farm', latitude: 0, longitude: 0, region: 'jp' },
        crop: {
          id: 7,
          name: 'Tomato',
          eligible: true,
          sowing_summary: null,
          transplant_summary: null,
          entry_disclaimer: 'Disclaimer',
          reason_summary: 'Summary',
          labels: { sowing: 'Sow', transplanting: 'Transplant' },
          sowing_windows: [],
          transplant_windows: [],
          reason_parts: {},
          sowing_stage_id: null,
          transplant_stage_id: null,
          crop_stages: [
            { id: 1, name: 'Germination', order: 1 },
            { id: 2, name: 'Vegetative growth', order: 2 }
          ]
        },
        prediction: {}
      })
    );

    fixture = TestBed.createComponent(EntryScheduleDetailComponent);
    translate.setTranslation('en', {
      'entrySchedule.title': 'Entry schedule',
      'entrySchedule.detailTitle': 'Crop schedule',
      'entrySchedule.stages': 'Growth stages'
    });
    translate.use('en');
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();

    const items = fixture.nativeElement.querySelectorAll('.stage-list li');
    expect(items.length).toBe(2);
    expect(items[0].textContent?.trim()).toBe('Germination');
    expect(items[1].textContent?.trim()).toBe('Vegetative growth');
    expect(fixture.nativeElement.textContent).not.toMatch(/\b1\.\s+1\./);
  });

  it('shows public plan CTA that hands off cropId to select-crop wizard', async () => {
    const router = TestBed.inject(Router);
    const navigateSpy = vi.spyOn(router, 'navigate');
    const publicPlanStore = TestBed.inject(PublicPlanStore);
    const gateway = TestBed.inject(ENTRY_SCHEDULE_GATEWAY);
    vi.mocked(gateway.getEntryScheduleCrop).mockReturnValue(
      of({
        farm: { id: 3, name: 'Farm', latitude: 35, longitude: 139, region: 'jp' },
        crop: {
          id: 7,
          name: 'Tomato',
          eligible: true,
          sowing_summary: null,
          transplant_summary: null,
          entry_disclaimer: 'Disclaimer',
          reason_summary: 'Summary',
          labels: { sowing: 'Sow', transplanting: 'Transplant' },
          sowing_windows: [],
          transplant_windows: [],
          reason_parts: {},
          sowing_stage_id: null,
          transplant_stage_id: null,
          crop_stages: []
        },
        prediction: {}
      })
    );

    fixture = TestBed.createComponent(EntryScheduleDetailComponent);
    translate.setTranslation('en', {
      entrySchedule: {
        title: 'Entry schedule',
        detailTitle: 'Crop schedule',
        ctaPublicPlan: 'Create free plan with this crop'
      }
    });
    translate.use('en');
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();

    const cta = fixture.nativeElement.querySelector(
      '.es-detail-cta-public-plan'
    ) as HTMLButtonElement;
    expect(cta).toBeTruthy();
    expect(cta.textContent?.trim()).toBe('Create free plan with this crop');

    cta.click();
    expect(publicPlanStore.state.farm?.id).toBe(3);
    expect(publicPlanStore.state.pendingCropId).toBe(7);
    expect(navigateSpy).toHaveBeenCalledWith(['/public-plans/select-crop']);
  });

  it('shows crop setup link when user is logged in', async () => {
    authUser = {
      id: 1,
      name: 'User',
      email: 'user@example.com',
      avatar_url: null,
      admin: false
    };

    const gateway = TestBed.inject(ENTRY_SCHEDULE_GATEWAY);
    vi.mocked(gateway.getEntryScheduleCrop).mockReturnValue(
      of({
        farm: { id: 3, name: 'Farm', latitude: 35, longitude: 139, region: 'jp' },
        crop: {
          id: 7,
          name: 'Tomato',
          eligible: true,
          sowing_summary: null,
          transplant_summary: null,
          entry_disclaimer: 'Disclaimer',
          reason_summary: 'Summary',
          labels: { sowing: 'Sow', transplanting: 'Transplant' },
          sowing_windows: [],
          transplant_windows: [],
          reason_parts: {},
          sowing_stage_id: null,
          transplant_stage_id: null,
          crop_stages: []
        },
        prediction: {}
      })
    );

    fixture = TestBed.createComponent(EntryScheduleDetailComponent);
    translate.setTranslation('en', {
      entrySchedule: {
        title: 'Entry schedule',
        detailTitle: 'Crop schedule',
        ctaCropSetup: 'Improve crop master'
      }
    });
    translate.use('en');
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();

    const link = fixture.nativeElement.querySelector(
      'a.es-detail-cta-setup'
    ) as HTMLAnchorElement;
    expect(link).toBeTruthy();
    expect(link.getAttribute('href')).toBe('/crops/7/setup_proposal');
    expect(link.textContent?.trim()).toBe('Improve crop master');
  });
});
