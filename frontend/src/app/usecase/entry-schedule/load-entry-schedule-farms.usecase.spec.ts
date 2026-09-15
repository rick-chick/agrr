import { HttpErrorResponse } from '@angular/common/http';
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { of, throwError, TimeoutError } from 'rxjs';
import { BACKEND_WARMUP_I18N } from '../../core/backend-warmup/backend-warmup';
import { LoadEntryScheduleFarmsUseCase } from './load-entry-schedule-farms.usecase';
import { LoadEntryScheduleFarmsOutputPort } from './load-entry-schedule-farms.output-port';
import { EntryScheduleGateway } from './entry-schedule-gateway';

describe('LoadEntryScheduleFarmsUseCase', () => {
  let outputPort: LoadEntryScheduleFarmsOutputPort;
  let gateway: EntryScheduleGateway;
  let useCase: LoadEntryScheduleFarmsUseCase;

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
    useCase = new LoadEntryScheduleFarmsUseCase(outputPort, gateway);
  });

  it('calls present when getEntryScheduleFarms succeeds', async () => {
    const farms = [{ id: 1, name: 'Farm A', region: 'jp', latitude: 35, longitude: 139 }];

    vi.mocked(gateway.getEntryScheduleFarms).mockReturnValue(of(farms));

    useCase.execute({ region: 'jp' });

    await new Promise((resolve) => setTimeout(resolve, 10));

    expect(outputPort.present).toHaveBeenCalledWith({ farms });
    expect(outputPort.onError).not.toHaveBeenCalled();
  });

  it('calls onError with apiErrorI18nKey when getEntryScheduleFarms fails', async () => {
    vi.mocked(gateway.getEntryScheduleFarms).mockReturnValue(
      throwError(() => new Error('Network error'))
    );

    useCase.execute({ region: 'jp' });

    await new Promise((resolve) => setTimeout(resolve, 10));

    expect(outputPort.onError).toHaveBeenCalledWith({ message: 'common.api_error.generic' });
    expect(outputPort.present).not.toHaveBeenCalled();
  });

  it('calls onError with warmup i18n key when getEntryScheduleFarms returns 503', async () => {
    vi.mocked(gateway.getEntryScheduleFarms).mockReturnValue(
      throwError(() => new HttpErrorResponse({ status: 503, statusText: 'Service Unavailable' }))
    );

    useCase.execute({ region: 'jp' });

    await new Promise((resolve) => setTimeout(resolve, 10));

    expect(outputPort.onError).toHaveBeenCalledWith({ message: BACKEND_WARMUP_I18N.database });
    expect(outputPort.present).not.toHaveBeenCalled();
  });

  it('calls onError with entrySchedule.timeout when request times out', async () => {
    vi.mocked(gateway.getEntryScheduleFarms).mockReturnValue(
      throwError(() => new TimeoutError())
    );

    useCase.execute({ region: 'jp' });

    await new Promise((resolve) => setTimeout(resolve, 10));

    expect(outputPort.onError).toHaveBeenCalledWith({ message: 'entrySchedule.timeout' });
    expect(outputPort.present).not.toHaveBeenCalled();
  });
});
