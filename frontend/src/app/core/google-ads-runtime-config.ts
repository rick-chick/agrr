import { environment } from '../../environments/environment';

declare global {
  interface Window {
    /** GCP デプロイ時の index.html 注入（または手動設定）と `environment.prod` の両方で利用 */
    GOOGLE_ADS_CONVERSION_ID?: string;
    /** 例: `AW-123456789/AbCdEfGhIj` … Google Ads「コンバージョンアクション」のタグ詳細にある send_to */
    GOOGLE_ADS_LOGIN_CONVERSION_SEND_TO?: string;
  }
}

export function getGoogleAdsConversionId(): string {
  const fromWindow =
    typeof window !== 'undefined' ? window.GOOGLE_ADS_CONVERSION_ID?.trim() : '';
  if (fromWindow) {
    return fromWindow;
  }
  return (environment.googleAdsId ?? '').trim();
}

export function getGoogleAdsLoginConversionSendTo(): string {
  const fromWindow =
    typeof window !== 'undefined' ? window.GOOGLE_ADS_LOGIN_CONVERSION_SEND_TO?.trim() : '';
  if (fromWindow) {
    return fromWindow;
  }
  return (environment.googleAdsLoginConversionSendTo ?? '').trim();
}
