/** ng serve --configuration gcp-test — same-origin proxy to Cloud Run (AGRR_TEST_API_URL optional). */
const target = (
  process.env.AGRR_TEST_API_URL || 'https://agrr-test-czyu2jck5q-an.a.run.app'
).replace(/\/$/, '');

// Strip upstream cookie Domain so session binds to the dev-server host (127.0.0.1:4201).
const api = { target, secure: true, changeOrigin: true, cookieDomainRewrite: '' };

module.exports = { '/api': api, '/auth': api, '/cable': { ...api, ws: true }, '/up': api };
