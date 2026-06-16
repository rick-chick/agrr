import { HttpHeaders } from '@angular/common/http';
import { TestBed } from '@angular/core/testing';
import { TranslateService } from '@ngx-translate/core';
import { firstValueFrom, of } from 'rxjs';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { ApiService } from '../../services/api.service';
import { EntryScheduleApiGateway } from './entry-schedule-api.gateway';

describe('EntryScheduleApiGateway', () => {
  let apiClient: { get: ReturnType<typeof vi.fn> };
  let translate: { currentLang: string; defaultLang: string };
  let gateway: EntryScheduleApiGateway;

  beforeEach(() => {
    TestBed.resetTestingModule();
    apiClient = {
      get: vi.fn()
    };
    translate = { currentLang: 'in', defaultLang: 'ja' };
    TestBed.configureTestingModule({
      providers: [
        EntryScheduleApiGateway,
        { provide: ApiService, useValue: apiClient },
        { provide: TranslateService, useValue: translate }
      ]
    });
    gateway = TestBed.inject(EntryScheduleApiGateway);
  });

  it('sends current ngx locale to entry schedule list API', async () => {
    apiClient.get.mockReturnValue(
      of({
        farm: { id: 1, name: 'Farm', latitude: 0, longitude: 0, region: 'in' },
        prediction: {},
        meta: { total_count: 0, limit: 20, next_cursor: null, has_more: false },
        crops: []
      })
    );

    await firstValueFrom(gateway.getEntryScheduleCrops(42));

    const options = apiClient.get.mock.calls[0][1] as { headers: HttpHeaders };
    expect(options.headers.get('Accept-Language')).toBe('in');
  });

  it('sends current ngx locale to entry schedule detail API', async () => {
    translate.currentLang = 'en';
    apiClient.get.mockReturnValue(
      of({
        farm: { id: 1, name: 'Farm', latitude: 0, longitude: 0, region: 'in' },
        prediction: {},
        crop: {
          id: 2,
          name: 'Crop',
          eligible: true,
          sowing_summary: null,
          transplant_summary: null,
          reason_summary: 'ok',
          labels: { sowing: 'Sowing', transplanting: 'Transplanting' },
          sowing_windows: [],
          transplant_windows: [],
          reason_parts: {},
          sowing_stage_id: null,
          transplant_stage_id: null,
          crop_stages: []
        }
      })
    );

    await firstValueFrom(gateway.getEntryScheduleCrop(1, 2));

    const options = apiClient.get.mock.calls[0][1] as { headers: HttpHeaders };
    expect(options.headers.get('Accept-Language')).toBe('en');
  });

  it('lets an explicit locale option override the current ngx locale', async () => {
    translate.currentLang = 'ja';
    apiClient.get.mockReturnValue(
      of({
        farm: { id: 1, name: 'Farm', latitude: 0, longitude: 0, region: 'in' },
        prediction: {},
        meta: { total_count: 0, limit: 20, next_cursor: null, has_more: false },
        crops: []
      })
    );

    await firstValueFrom(gateway.getEntryScheduleCrops(42, { locale: 'in' }));

    const options = apiClient.get.mock.calls[0][1] as { headers: HttpHeaders };
    expect(options.headers.get('Accept-Language')).toBe('in');
  });
});
