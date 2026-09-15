import { HttpErrorResponse } from '@angular/common/http';
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { of, throwError } from 'rxjs';
import { BACKEND_WARMUP_I18N } from '../../core/backend-warmup/backend-warmup';
import { LoadEntryScheduleCropUseCase } from './load-entry-schedule-crop.usecase';
import { LoadEntryScheduleCropOutputPort } from './load-entry-schedule-crop.output-port';
import { EntryScheduleGateway } from './entry-schedule-gateway';

describe('LoadEntryScheduleCropUseCase', () => {
  let outputPort: LoadEntryScheduleCropOutputPort;
  let gateway: EntryScheduleGateway;
  let useCase: LoadEntryScheduleCropUseCase;

  const data = {
    farm: { id: 3, name: 'Farm', latitude: 35, longitude: 139, region: 'jp' },
    crop: {
      id: 7,
      name: 'Tomato',
      eligible: true,
      sowing_summary: null,
      transplant_summary: null,
      entry_disclaimer: 'Disclaimer',
      reason_summary: 'Summary',
      reason_parts: {},
      sowing_stage_id: null,
      transplant_stage_id: null,
      labels: { sowing: 'Sow', transplanting: 'Transplant' },
      sowing_windows: [],
      transplant_windows: [],
      crop_stages: []
    },
    prediction: {}
  };

  beforeEach(() => {
    outputPort = {
      present: vi.fn(),
      onError: vi.fn()
    };
    gateway = {
      getEntryScheduleFarms: vi.fn(),
      getEntryScheduleCrops: vi.fn(),
      getEntryScheduleCrop: vi.fn()
    };
    useCase = new LoadEntryScheduleCropUseCase(outputPort, gateway);
  });

  it('calls present when getEntryScheduleCrop succeeds', async () => {
    vi.mocked(gateway.getEntryScheduleCrop).mockReturnValue(of(data));

    useCase.execute({ farmId: 3, cropId: 7 });

    await new Promise((resolve) => setTimeout(resolve, 10));

    expect(gateway.getEntryScheduleCrop).toHaveBeenCalledWith(3, 7);
    expect(outputPort.present).toHaveBeenCalledWith({ data });
    expect(outputPort.onError).not.toHaveBeenCalled();
  });

  it('calls onError with apiErrorI18nKey when getEntryScheduleCrop fails', async () => {
    vi.mocked(gateway.getEntryScheduleCrop).mockReturnValue(
      throwError(() => new Error('Network error'))
    );

    useCase.execute({ farmId: 3, cropId: 7 });

    await new Promise((resolve) => setTimeout(resolve, 10));

    expect(outputPort.onError).toHaveBeenCalledWith({ message: 'common.api_error.generic' });
    expect(outputPort.present).not.toHaveBeenCalled();
  });

  it('calls onError with warmup i18n key when getEntryScheduleCrop returns 503', async () => {
    vi.mocked(gateway.getEntryScheduleCrop).mockReturnValue(
      throwError(() => new HttpErrorResponse({ status: 503, statusText: 'Service Unavailable' }))
    );

    useCase.execute({ farmId: 3, cropId: 7 });

    await new Promise((resolve) => setTimeout(resolve, 10));

    expect(outputPort.onError).toHaveBeenCalledWith({ message: BACKEND_WARMUP_I18N.database });
    expect(outputPort.present).not.toHaveBeenCalled();
  });
});
