#!/usr/bin/env bash
# Verify SEO-related HTTP responses on production (or BASE_URL).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BASE_URL="${BASE_URL:-https://agrr.net}"
BASE_URL="${BASE_URL%/}"

failures=0

normalize_status() {
  echo "$1" | tr -d '\r' | xargs
}

check_status() {
  local label="$1"
  local url="$2"
  local expected="$3"
  local actual
  actual="$(normalize_status "$(curl -sI "$url" | head -1)")"
  if [[ "$actual" != "$expected" ]]; then
    echo "FAIL $label: expected '$expected', got '$actual' ($url)"
    failures=$((failures + 1))
  else
    echo "OK   $label"
  fi
}

check_redirect_location() {
  local label="$1"
  local url="$2"
  local expected_location="$3"
  local location
  location="$(curl -sI "$url" | tr -d '\r' | awk -F': ' 'tolower($1)=="location"{print $2; exit}' | xargs)"
  expected_location="$(echo "$expected_location" | xargs)"
  location="${location/:443/}"
  expected_location="${expected_location/:443/}"
  if [[ "$location" != "$expected_location" ]]; then
    echo "FAIL $label: expected Location '$expected_location', got '$location' ($url)"
    failures=$((failures + 1))
  else
    echo "OK   $label"
  fi
}

check_status "root" "$BASE_URL/" "HTTP/2 200"
check_status "about" "$BASE_URL/about" "HTTP/2 200"
check_status "public-plans-new" "$BASE_URL/public-plans/new" "HTTP/2 200"
check_status "login" "$BASE_URL/login" "HTTP/2 200"
check_status "public-plans-results" "$BASE_URL/public-plans/results?planId=1" "HTTP/2 200"
check_status "public-plans-optimizing" "$BASE_URL/public-plans/optimizing?planId=1" "HTTP/2 200"
check_status "robots.txt" "$BASE_URL/robots.txt" "HTTP/2 200"
check_status "sitemap.xml" "$BASE_URL/sitemap.xml" "HTTP/2 200"
check_status "research-index" "$BASE_URL/research/" "HTTP/2 200"
check_status "research-html" "$BASE_URL/research/research_reports/radish/03_pest_disease/major_pests.html" "HTTP/2 200"
check_status "research-extensionless-404" "$BASE_URL/research/research_reports/radish/03_pest_disease/major_pests" "HTTP/2 404"

# Internal work files must not be publicly reachable (H3).
check_status "research-internal-commands-template" "$BASE_URL/research/research_reports/commands_template.html" "HTTP/2 404"
check_status "research-internal-tomato-commands" "$BASE_URL/research/research_reports/tomato/commands.html" "HTTP/2 404"
check_status "research-internal-terminology-survey" "$BASE_URL/research/research_reports/%E7%94%A8%E8%AA%9E%E7%B5%B1%E4%B8%80%E8%BF%BD%E5%8A%A0%E8%AA%BF%E6%9F%BB%E7%B5%90%E6%9E%9C2.html" "HTTP/2 404"
check_status "research-internal-readability-list" "$BASE_URL/research/research_reports/%E8%AA%AD%E3%81%BF%E3%81%AB%E3%81%8F%E3%81%84%E3%83%BB%E7%B5%B1%E4%B8%80%E3%81%95%E3%82%8C%E3%81%A6%E3%81%84%E3%81%AA%E3%81%84%E7%AE%87%E6%89%80%E3%83%AA%E3%82%B9%E3%83%88.html" "HTTP/2 404"

check_status "www-redirect" "https://www.agrr.net/" "HTTP/2 301"
check_redirect_location "www-redirect-location" "https://www.agrr.net/" "https://agrr.net/"

check_status "legacy-public-plans" "$BASE_URL/public_plans" "HTTP/2 301"
check_redirect_location "legacy-public-plans-location" "$BASE_URL/public_plans" "$BASE_URL/public-plans/new"

check_status "legacy-us-about" "$BASE_URL/us/about" "HTTP/2 301"
check_redirect_location "legacy-us-about-location" "$BASE_URL/us/about" "$BASE_URL/about"

legacy_research_status="$(normalize_status "$(curl -sI "$BASE_URL/research_reports/radish/03_pest_disease/major_pests.html" | head -1)")"
if [[ "$legacy_research_status" != "HTTP/2 301" && "$legacy_research_status" != "HTTP/2 404" ]]; then
  echo "FAIL legacy-research-prefix: expected HTTP/2 301 or 404, got '$legacy_research_status'"
  failures=$((failures + 1))
else
  echo "OK   legacy-research-prefix ($legacy_research_status)"
fi

robots_type="$(curl -sI "$BASE_URL/robots.txt" | tr -d '\r' | awk -F': ' 'tolower($1)=="content-type"{print tolower($2); exit}')"
if [[ "$robots_type" != *"text/plain"* ]]; then
  echo "FAIL robots content-type: $robots_type"
  failures=$((failures + 1))
else
  echo "OK   robots content-type"
fi

sitemap_body="$(curl -s "$BASE_URL/sitemap.xml")"
sitemap_urls="$(echo "$sitemap_body" | grep -c '<url>' || true)"
if [[ "$sitemap_urls" -lt 100 ]]; then
  echo "FAIL sitemap url count: $sitemap_urls (expected >= 100)"
  failures=$((failures + 1))
else
  echo "OK   sitemap url count ($sitemap_urls)"
fi

sitemap_forbidden_patterns=(
  'commands_template'
  'tomato/commands.html'
  '%E7%94%A8%E8%AA%9E%E7%B5%B1%E4%B8%80'
  '%E8%AA%AD%E3%81%BF%E3%81%AB%E3%81%8F%E3%81%84'
)
for pattern in "${sitemap_forbidden_patterns[@]}"; do
  if echo "$sitemap_body" | grep -q "$pattern"; then
    echo "FAIL sitemap contains internal work file pattern: $pattern"
    failures=$((failures + 1))
  else
    echo "OK   sitemap excludes internal pattern ($pattern)"
  fi
done

if [[ "$failures" -gt 0 ]]; then
  echo "SEO routing verification failed ($failures failure(s))."
  exit 1
fi

echo "SEO routing verification passed."
echo "Next: ${SCRIPT_DIR}/submit-sitemap-gsc.sh"
