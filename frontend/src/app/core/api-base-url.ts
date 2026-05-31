import { environment } from '../../environments/environment';

/**
 * APIベースURLを取得する。
 *
 * - window.API_BASE_URL が設定されている場合はそれを使用
 * - `environment.proxySameOriginApi`（development / gcp-test）のときは ''（dev-server proxy が /api へ転送）
 * - それ以外（Rails から配信される本番ビルド等）は '' を使用（同一オリジン）
 */
export function getApiBaseUrl(): string {
  const env = (window as { API_BASE_URL?: string }).API_BASE_URL;
  if (env !== undefined && env !== '') {
    return env;
  }
  if ('proxySameOriginApi' in environment && environment.proxySameOriginApi) {
    return '';
  }
  return '';
}
