/**
 * APIベースURLを取得する。
 *
 * - window.API_BASE_URL が設定されている場合はそれを使用
 * - 未設定かつ Angular 開発サーバー (localhost:4200) の場合は http://localhost:3000 を使用
 * - それ以外（Rails から配信される本番ビルド等）は '' を使用（同一オリジン）
 */
export function getApiBaseUrl(): string {
  const env = (window as { API_BASE_URL?: string }).API_BASE_URL;
  if (env !== undefined && env !== '') {
    return env;
  }
  if (
    typeof location !== 'undefined' &&
    location.hostname === 'localhost' &&
    location.port === '4200'
  ) {
    return 'http://localhost:3000';
  }
  return '';
}
