export const environment = {
  production: false,
  enableGoogleAnalytics: false,
  googleAnalyticsMeasurementId: 'G-WNLSL6W4ZT',
  /** Google Ads のコンバージョンタグ ID（例: AW-123456789）。本番は deploy の window 注入を推奨。 */
  googleAdsId: '',
  /** ログイン完了時のサイトコンバージョン send_to（例: AW-123456789/XyZ）。空なら転換イベントは送らない。 */
  googleAdsLoginConversionSendTo: ''
};
