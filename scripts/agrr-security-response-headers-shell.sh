# Shared shell constants for agrr.net security response headers.
# Keep in sync with scripts/agrr-security-response-headers-lib.mjs

SECURITY_RESPONSE_HEADERS=(
  'Strict-Transport-Security: max-age=31536000; includeSubDomains'
  'X-Content-Type-Options: nosniff'
  'Referrer-Policy: strict-origin-when-cross-origin'
  'X-Frame-Options: DENY'
  "Content-Security-Policy-Report-Only: default-src 'self'; script-src 'self' 'unsafe-inline' https://www.googletagmanager.com https://www.google-analytics.com; connect-src 'self' https://www.google-analytics.com https://region1.google-analytics.com https://www.googletagmanager.com; img-src 'self' data: https://www.google-analytics.com https://www.googletagmanager.com; style-src 'self' 'unsafe-inline'; frame-ancestors 'none'"
)
