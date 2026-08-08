const { buildAuthConfig } = require('./scripts/lighthouse-ci-lighthouserc-lib.cjs');

const config = buildAuthConfig();
if (!config) {
  throw new Error('lighthouserc.auth.js requires scripts/lighthouse-ci-auth-urls.json');
}

module.exports = config;
