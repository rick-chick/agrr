import { HttpErrorResponse } from '@angular/common/http';
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { of, throwError, TimeoutError } from 'rxjs';
import { BACKEND_WARMUP_I18N } from '../../core/backend-warmup/backend-warmup';
import { LoadEntryScheduleCropsUseCase } from './load-entry-schedule-crops.usecase';
import { LoadEntryScheduleCropsOutputPort } from './load-entry-schedule-crops.output-port';
import { EntryScheduleGateway } from './entry-schedule-gateway';

describe('LoadEntryScheduleCropsUseCase', () => {
  let outputPort: LoadEntryScheduleCropsOutputPort;
  let gateway: EntryScheduleGateway;
  let useCase: LoadEntryScheduleCropsUseCase;

  const response = {
    farm: { id: 1, name: 'Farm A', latitude: 35, longitude: 139, region: 'jp' },
    crops: [],
    prediction: {},
    meta: { total_count: 0, limit: 20, has_more: false, next_cursor: null }
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
    useCase = new LoadEntryScheduleCropsUseCase(outputPort, gateway);
  });

  it('calls present when getEntryScheduleCrops succeeds', async () => {
    vi.mocked(gateway.getEntryScheduleCrops).mockReturnValue(of(response));

    useCase.execute({ farmId: 1, append: false, limit: 20 });

    await new Promise((resolve) => setTimeout(resolve, 10));

    expect(gateway.getEntryScheduleCrops).toHaveBeenCalledWith(1, { limit: 20, cursor: undefined });
    expect(outputPort.present).toHaveBeenCalledWith({ response, append: false });
    expect(outputPort.onError).not.toHaveBeenCalled();
  });

  it('passes cursor when append is true', async () => {
    vi.mocked(gateway.getEntryScheduleCrops).mockReturnValue(of(response));

    useCase.execute({ farmId: 1, append: true, limit: 20, cursor: 'page-2' });

    await new Promise((resolve) => setTimeout(resolve, 10));

    expect(gateway.getEntryScheduleCrops).toHaveBeenCalledWith(1, {
      limit: 20,
      cursor: 'page-2'
    });
    expect(outputPort.present).toHaveBeenCalledWith({ response, append: true });
  });

  it('calls onError with apiErrorI18nKey when getEntryScheduleCrops fails', async () => {
    vi.mocked(gateway.getEntryScheduleCrops).mockReturnValue(
      throwError(() => new Error('Network error'))
    );

    useCase.execute({ farmId: 1, append: false, limit: 20 });

    await new Promise((resolve) => setTimeout(resolve, 10));

    expect(outputPort.onError).toHaveBeenCalledWith({ message: 'common.api_error.generic' });
    expect(outputPort.present).not.toHaveBeenCalled();
  });

  it('calls onError with warmup i18n key when getEntryScheduleCrops returns 503', async () => {
    vi.mocked(gateway.getEntryScheduleCrops).mockReturnValue(
      throwError(() => new HttpErrorResponse({ status: 503, statusText: 'Service Unavailable' }))
    );

    useCase.execute({ farmId: 1, append: false, limit: 20 });

    await new Promise((resolve) => setTimeout(resolve, 10));

    expect(outputPort.onError).toHaveBeenCalledWith({ message: BACKEND_WARMUP_I18N.database });
    expect(outputPort.present).not.toHaveBeenCalled();
  });

  it('calls onError with entrySchedule.timeout when request times out', async () => {
    vi.mocked(gateway.getEntryScheduleCrops).mockReturnValue(
      throwError(() => new TimeoutError())
    );

    useCase.execute({ farmId: 1, append: false, limit: 20 });

    await new Promise((resolve) => setTimeout(resolve, 10));

    expect(outputPort.onError).toHaveBeenCalledWith({ message: 'entrySchedule.timeout' });
    expect(outputPort.present).not.toHaveBeenCalled();
  });
});
