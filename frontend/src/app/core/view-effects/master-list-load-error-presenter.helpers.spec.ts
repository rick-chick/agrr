import { masterListLoadErrorFromDto } from './master-list-load-error-presenter.helpers';

describe('masterListLoadErrorFromDto', () => {
  it('returns i18n key when scope matches load-list scope', () => {
    expect(
      masterListLoadErrorFromDto({ message: 'Http failure response: 0 Unknown Error', scope: 'load-farm-list' }, 'load-farm-list')
    ).toBe('common.api_error.network');
  });

  it('returns null when scope does not match load-list scope', () => {
    expect(
      masterListLoadErrorFromDto({ message: 'Delete failed', scope: 'delete-farm' }, 'load-farm-list')
    ).toBeNull();
  });
});
