/** ng serve (development) — same-origin proxy to local strangler (nginx :3000 → agrr-server). */
const target = (process.env.AGRR_DEV_API_URL || 'http://127.0.0.1:3000').replace(/\/$/, '');

const api = { target, secure: false, changeOrigin: true, cookieDomainRewrite: '' };

// Vite dev-server: `/auth` は `/auth` 完全一致のみ。サブパスは `/**` が必要（Angular ng serve ドキュメント）
module.exports = {
  '/api/**': api,
  '/auth/**': api,
  '/cable': { ...api, ws: true },
  '/up': api,
  // UndoToastService posts here after masters DELETE (not under /api).
  '/undo_deletion': api
};
