# Angular static hosting on GCP — design notes

This document describes a simple, repeatable hosting architecture for serving an Angular SPA from a GCS bucket + Cloud CDN. It covers bucket naming, cache-control, CORS, HTTPS, IAM roles, CDN invalidation strategy, and how to inject `API_BASE_URL` at deployment time. Keep this concise and actionable.

---

## Architecture overview

- Build artifacts (Angular `dist/`) are synced to a GCS bucket (backend: `gs://<BUCKET_NAME>`).
- A backend-bucket or backend-service is attached to an external HTTP(S) Load Balancer with Cloud CDN enabled, fronted by a global HTTPS IP and domain.
- Cloud CDN caches responses globally; cache-control headers decide TTLs and cache policy.
- Use HTTPS via a managed certificate attached to the Load Balancer (or use Cloud CDN + HTTPS Load Balancer).
- Use a simple deploy script to:
  1. build the SPA,
  2. inject `window.API_BASE_URL` into `index.html`,
  3. sync files with `gsutil rsync`,
  4. set proper `Cache-Control` metadata,
  5. invalidate CDN cache (URL map invalidation).

## SPA routing fallback

GCS buckets return `404 Not Found` for any path that has no object, which breaks client-side routing (`/url/hogehuga` should still load your SPA). Configure the HTTPS Load Balancer URL map to rewrite unmatched requests to `index.html` while keeping API routes intact.

1. Create or edit the URL map so the default backend is the frontend backend bucket and the default route action rewrites every request path to `/index.html`:

```bash
gcloud compute url-maps add-path-matcher $URL_MAP_NAME \
  --global \
  --path-matcher-name spa-fallback \
  --default-service projects/$PROJECT_ID/global/backendBuckets/$BUCKET_NAME \
  --default-route-action='urlRewrite.pathPrefixRewrite=/index.html'
```

2. Route API or other non-SPA paths before the default rule. For example:

```bash
  --path-rules='/api/*=projects/$PROJECT_ID/global/backendServices/api-service'
```

3. Alternatively, edit an existing map interactively:

```bash
gcloud compute url-maps edit $URL_MAP_NAME --global
```

and add a `pathMatcher` block that rewrites to `/index.html` while forwarding `/api/*` (and other backend traffic) to their respective services.

By keeping `/*` as the SPA default rewrite and explicitly routing backend paths, the load balancer can serve all client-side routes through `index.html` without interfering with API endpoints.

---

## Bucket naming convention

Use descriptive, environment-scoped names to avoid accidental overwrites:

- Production: `<project-id>-frontend-prod` (e.g. `agrr-prod-frontend`)
- Test: `<project-id>-frontend-test` (e.g. `agrr-test-frontend`)

Bucket names must be globally unique and lowercase, no underscores.

Example:
- `BUCKET_NAME=agrr-frontend-prod`
- `TEST_BUCKET_NAME=agrr-frontend-test`

---

## Cache-Control strategy

Set metadata on objects after upload:

- `index.html` (app shell / entrypoint)
  - Cache-Control: `no-cache, max-age=0, must-revalidate`
  - Rationale: always check for new HTML so clients get new application bootstrap quickly.
- Static assets (JS/CSS/images/fonts)
  - Cache-Control: `public, max-age=31536000, immutable`
  - Rationale: build outputs include content-hashed filenames; safe to cache long-term.

Commands (after sync; examples target `gs://$BUCKET`):

- Set index.html no-cache
  - gsutil setmeta -h "Cache-Control: no-cache, max-age=0, must-revalidate" gs://$BUCKET/index.html
- Set assets long cache
  - gsutil -m setmeta -h "Cache-Control: public, max-age=31536000, immutable" "gs://$BUCKET/**/*.js" "gs://$BUCKET/**/*.css" "gs://$BUCKET/**/*.woff2" "gs://$BUCKET/**/*.png"

Note: quoting/wildcard support depends on your shell and gsutil version; use the script for robust handling.

---

## CORS

If your frontend calls APIs on different domains (e.g. api.example.com), configure CORS on the API side. For static hosting, you may need CORS for fonts or preflighted requests; configure a small `cors.json` and apply:

Example `cors.json`:
```json
[
  {
    "origin": ["https://www.example.com"],
    "method": ["GET", "HEAD"],
    "responseHeader": ["Content-Type"],
    "maxAgeSeconds": 3600
  }
]
```

Apply:
- gsutil cors set cors.json gs://$BUCKET

---

## HTTPS and domain

- Use a global HTTPS Load Balancer with a backend-bucket (or backend service) that points to the GCS bucket.
- Attach a Google-managed certificate for your domain to the HTTPS proxy.
- Alternative: use the bucket website endpoint with a custom CDN + HTTPS LB to get custom domain and managed certs.

---

## IAM roles

Grant the minimum roles required:

- Deployment principal (CI / deployer service account)
  - roles/storage.objectAdmin (or more narrowly, `roles/storage.admin` for bucket management)
  - roles/compute.networkAdmin or roles/compute.admin is NOT required for simple invalidation — you only need permission to call `gcloud compute url-maps invalidate-cdn-cache`:
    - roles/compute.securityAdmin or roles/compute.loadBalancerAdmin may be required depending on organization policies. Prefer creating a scoped role that allows `compute.urlMaps.invalidateCdnCache`.
- For managed certs and load balancer operations (if used in CI): roles/compute.admin (or a narrower role covering load balancer and certificates).

Example to grant storage object admin to a service account:
- gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:$SA_EMAIL" --role="roles/storage.objectAdmin"

---

## CDN invalidation strategy

Options:
- Full-path invalidation (fast, simple): invalidate `/*` after deploy.
- Granular invalidation: invalidate only changed file paths (requires tracking changed filenames).

Commands:
- Invalidate all cache via URL map:
  - gcloud compute url-maps invalidate-cdn-cache $URL_MAP_NAME --path "/*" --project $PROJECT_ID
- Or invalidate individual paths:
  - gcloud compute url-maps invalidate-cdn-cache $URL_MAP_NAME --path "/main.*.js" --project $PROJECT_ID

Notes:
- Invalidations may incur cost; prefer long-lived asset caching + HTML no-cache pattern so only HTML is fetched fresh and assets stay cached.
- Use the deploy script to call invalidation automatically after successful sync (optional / configurable).

---

## Injecting API_BASE_URL at deployment time

Two common approaches:

1. Build-time environment replacement
   - Use Angular environment files or a build-time variable to bake the API base URL into the bundle.
   - Downside: requires rebuilding for each environment.

2. Runtime injection (recommended for static builds)
   - Insert a small inline script into `index.html` during deploy that sets `window.API_BASE_URL` before the app bootstraps.
   - Example script inserted into `index.html`:
     ```html
     <script>
       window.API_BASE_URL = "https://api-test.example.com";
     </script>
     ```
   - Place this before the main bundle is loaded (inside `<head>` or at the top of `<body>`), or have your app read `window.API_BASE_URL` during bootstrap.

The provided deploy script implements runtime injection by editing the built `dist/index.html` (safe because index.html is not aggressively cached).

---

## Example commands (manual, step-by-step)

1. Create bucket:
  - gsutil mb -l $REGION -p $PROJECT_ID gs://$BUCKET_NAME

2. Make bucket public (if using public content and public website):
  - gsutil iam ch allUsers:objectViewer gs://$BUCKET_NAME

3. Set CORS (optional):
  - echo '[ { "origin": ["https://www.example.com"], "method": ["GET","HEAD"], "responseHeader": ["Content-Type"], "maxAgeSeconds": 3600 } ]' > cors.json
  - gsutil cors set cors.json gs://$BUCKET_NAME

4. Build and deploy (example; use provided script in repo for full flow)
  - PROJECT_ID=my-project REGION=us-central1 BUCKET_NAME=agrr-frontend-test API_BASE_URL=https://api-test.example.com \
    ./scripts/gcp-frontend-deploy.sh deploy test

5. CDN invalidation (example):
  - gcloud compute url-maps invalidate-cdn-cache $URL_MAP_NAME --path "/*" --project $PROJECT_ID

---

## Notes & best practices

- Do not set long cache TTL on `index.html`. Use no-cache for HTML + long TTL for hashed assets.
- Favor runtime injection for `API_BASE_URL` to avoid rebuilding artifacts per environment.
- Use service accounts for CI with least privilege: storage.objectAdmin + permission to invalidate CDN (urlMap invalidate permission).
- Avoid public write access on the bucket. Grant the CI service account `roles/storage.objectAdmin`.

This design is intentionally minimal and practical — use the included deploy script for a repeatable workflow.

