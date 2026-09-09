import { describe, expect, it } from 'vitest';
import { BACKEND_WARMUP_I18N } from '../../core/backend-warmup/backend-warmup';
import { masterLoadErrorFromDto } from './master-load-error-presenter.helpers';

describe('masterLoadErrorFromDto', () => {
  it('classifies 502 HTTP failure as warmup error', () => {
    const result = masterLoadErrorFromDto({
      message:
        'Http failure response for https://agrr.local/api/v1/masters/crops/1: 502 Bad Gateway'
    });

    expect(result).toEqual({
      errorKey: BACKEND_WARMUP_I18N.database,
      isWarmupError: true
    });
  });

  it('classifies 503 HTTP failure as warmup error', () => {
    const result = masterLoadErrorFromDto({
      message:
        'Http failure response for https://agrr.local/api/v1/masters/crops/1: 503 Service Unavailable'
    });

    expect(result).toEqual({
      errorKey: BACKEND_WARMUP_I18N.database,
      isWarmupError: true
    });
  });

  it('classifies generic load failure as non-warmup error', () => {
    const result = masterLoadErrorFromDto({ message: 'Something went wrong' });

    expect(result).toEqual({
      errorKey: 'common.api_error.generic',
      isWarmupError: false
    });
  });
});
