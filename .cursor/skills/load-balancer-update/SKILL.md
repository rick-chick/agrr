---
name: load-balancer-update
description: Guide the agent through exporting, editing, and validating GCP URL map configurations when the user requests a load balancer update. Use whenever a user asks about updating URL map rules, path matchers, or host/path routing on the load balancer.
---

# Load Balancer Update Guidance

## 1. Capture the current URL map

- Export the existing map to a tracked YAML file (avoid `/tmp` if you want to reuse it).
  ```
  gcloud compute url-maps export agrr-frontend-url-map-simple \
    --destination=scripts/agrr-frontend-url-map-simple.yaml --global --project=agrr-475323
  ```
- Store the YAML under `scripts/` or another repo directory so changes are versioned and reusable.

## 2. Edit routing rules safely

- Preserve the high-level structure (`defaultService`, `hostRules`, path matcher names) to avoid disrupting existing traffic.
- For API, auth, and Rails routes keep the `pathRules` that already work.
- For static file extensions, switch to `routeRules` with `pathTemplateMatch` or supported `regexMatch` patterns, e.g.:
  ```yaml
  routeRules:
  - priority: 1000
    matchRules:
    - pathTemplateMatch: '/{file=**.css}'
    service: https://.../frontend-backend
  ```
- Group multiple extensions into one rule set by listing multiple `matchRules` entries. Use `**` to capture the suffix and optionally rewrite with `urlRewrite`.

## 3. Apply and verify

- After editing, run:
  ```
  gcloud compute url-maps validate agrr-frontend-url-map-simple \
    --source=scripts/agrr-frontend-url-map-simple.yaml --global --project=agrr-475323
  ```
- When validation succeeds, import the YAML:
  ```
  gcloud compute url-maps import agrr-frontend-url-map-simple \
    --source=scripts/agrr-frontend-url-map-simple.yaml --global --project=agrr-475323
  ```
- Use `gcloud compute url-maps describe` to confirm host/path rules reflect the intended backend assignments.

## Checklist

- [ ] Exported the current map to `scripts/` or another tracked location.
- [ ] Added extension-level routing via `routeRules`/`pathTemplateMatch` instead of unsupported `/*.ext` path rules.
- [ ] Kept `defaultService`, host rules, and Rails path rules unchanged.
- [ ] Validated the YAML with `gcloud ... validate` before importing.
