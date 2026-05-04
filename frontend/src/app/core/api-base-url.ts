/**
 * APIベースURLを取得する。
 *
 * - window.API_BASE_URL が設定されている場合はそれを使用
 * - 未設定かつ Angular 開発サーバー (localhost:4200 / 127.0.0.1:4200) の場合は
 *   同一ループバックの Rails (3000) を使用（ng serve の --host と揃える）
 * - それ以外（Rails から配信される本番ビルド等）は '' を使用（同一オリジン）
 */
export function getApiBaseUrl(): string {
  const env = (window as { API_BASE_URL?: string }).API_BASE_URL;
  if (env !== undefined && env !== '') {
    return env;
  }
  if (typeof location === 'undefined') {
    return '';
  }
  const host = location.hostname;
  const port = location.port;
  if (host === 'localhost' && port === '4200') {
    return 'http://localhost:3000';
  }
  if (host === '127.0.0.1' && port === '4200') {
    return 'http://127.0.0.1:3000';
  }
  return '';
}
