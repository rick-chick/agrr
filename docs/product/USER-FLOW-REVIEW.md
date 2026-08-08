# 導線レビュー（2026-06-11）

フロントエンド SPA のルート定義・ナビゲーション・認証導線・CDN URL マップ・SEO 導線を横断レビューした結果。対象は `frontend/src/app/routes/`、`frontend/src/app/components/`、`scripts/agrr-frontend-url-map-simple.yaml`、`frontend/public/{sitemap.xml,robots.txt}`、`crates/agrr-server/src/{auth.rs,auth_return_to.rs}`。

ステータス凡例: 🔴 修正推奨（ユーザー影響あり） / 🟡 改善余地 / 🟢 意図的・記録のみ / ✅ 対応済み（2026-08 受け入れ確認）

---

## 🔴 High

### H1. authGuard がリダイレクト時に return_to を保持しない — ✅ 対応済み

**対応**: `frontend/src/app/guards/auth.guard.ts` が `loginReturnQueryForLocation` 経由で `return_to` を付与して `/login` へ遷移する（`router.createUrlTree(['/login'], { queryParams })`）。

- 元の指摘: 未認証時に `router.parseUrl('/login')` のみで深いリンクが失われる。
- 確認: `login-auth-urls.ts` の `navigateTargetFromReturnTo` とガード・navbar で同一契約。

### H2. ログイン済みで /login に来ると return_to を無視して `/` へ — ✅ 対応済み

**対応**: `frontend/src/app/components/auth/login/login.component.ts` が `loadCurrentUser()` 成功時に `navigateTargetFromReturnTo(return_to)` を検証し、有効なら `navigateByUrl` で復帰する。

- 元の指摘: セッション済みで `/login?return_to=...` に来たとき無条件 `/` へ飛ぶ。
- 確認: 公開プラン保存導線（`public-plan-results.component.ts`）のエッジケースを解消。

### H3. sitemap.xml に内部作業ファイルが露出

`frontend/public/sitemap.xml` に以下が含まれ、公開・クローラのインデックス対象になっている:

- `https://agrr.net/research/research_reports/読みにくい・統一されていない箇所リスト.html`
- `https://agrr.net/research/research_reports/用語統一追加調査結果2.html`
- `https://agrr.net/research/research_reports/commands_template.html`
- `https://agrr.net/research/research_reports/tomato/commands.html`

これらは調査メモ・コマンドテンプレートであり、ユーザー向け導線（research レポート）ではない。sitemap 生成時の除外に加え、`agrr-research-backend` バケット側からの削除（公開導線からの撤去）も必要。


---

## 🟡 Medium

### M1. /dashboard ルートがレガシーのまま残存

`frontend/src/app/routes/core.routes.ts:10` — `/dashboard` は authGuard 付きで `HomeComponent`（公開マーケティングページと同一）を表示するだけ。アプリ内に参照は一切なく、`AUTH_REQUIRED_PREFIXES`（フロント・Rust 両方）にも残っている。導線として意味を持たないため、削除するか、ログイン後ホームとして実体を持たせるか方針を決めるべき。

### M2. 未知 URL が HTTP 200 で返る（soft 404）

`scripts/agrr-frontend-url-map-simple.yaml` の catch-all（`/*` → `/index.html` rewrite）により、存在しないパスも 200 + SPA シェルが返り、`NotFoundComponent` を表示しても HTTP ステータスは 200。`not-found.component.ts` は `noindex` メタも設定していない。SPA + CDN 構成での既知のトレードオフだが、最低限 NotFound 表示時に `<meta name="robots" content="noindex">` を動的設定すべき。

### M3. ルーター遷移時のスクロール位置復元が未設定 — ✅ 対応済み

**対応**: `frontend/src/app/app-router-features.ts` が `withInMemoryScrolling({ scrollPositionRestoration: 'enabled', anchorScrolling: 'enabled' })` を `app.config.ts` 経由で提供する。

- 元の指摘: 一覧→詳細遷移でスクロール位置が引き継がれ、戻る復元も効かない。

### M4. `_post_login` クエリが未認証時に URL に残留する

`frontend/src/app/app.ts:97` — `maybeNavigatePostLogin()` はセッション確立に失敗した場合（`authService.user()` が null）に早期 return し、`/?_post_login=...` のクエリを消費しない。ユーザーには意味不明なクエリ付きホームが残る。認証失敗時もクエリを除去（`replaceUrl`）すべき。

---

## 🟢 確認済み・意図的（記録のみ）

- **M5 対応**: in ロケールのレポート導線を英語版 `/research/en/` にフォールバック（#735）。
- **entry-schedule のナビ非表示**: `navbar.component.ts:40` にコメントで明示（「未成熟のためナビから非表示。ルートは残す」）。ルート自体は到達可能で、画面内の相互リンク（一覧⇔詳細）は整合。
- **公開プランフローの状態ガード**: `/public-plans/select-crop` は farm 未設定時に `/public-plans/new` へ、`/public-plans/optimizing` は planId 解決不能時に `/public-plans/new` へリダイレクト。直接着地しても破綻しない。
- **AUTH_REQUIRED_PREFIXES の同期**: `login-auth-urls.ts` と `crates/agrr-server/src/auth_return_to.rs` で一致を確認（9 プレフィックス）。
- **H4 対応（削除）**: `/weather` と `/api-keys` はナビ導線がなくオーファンだったためルートごと削除。気象データは農場詳細・計画気候チャート等の既存画面経由。API キー管理 UI は廃止（`ApiKeyService` によるセッションキー付与は継続）。
- **`/auth/login` 直接着地**: URL マップでは rust-backend に渡るが、`auth.rs:33` の `login_page` が SPA の `/login` へ `return_to` 維持でリダイレクト。SPA 内ナビは `core.routes.ts` の `auth/login → login` redirect で処理。二重に整合。
- **レガシー URL リダイレクト**: `/public_plans/*`、`/us/*`、`/in/*`、`/public-plans/select-farm-size` は URL マップ・SPA ルートで 301/redirect 済み。
- **マスタ系ルート順序**: `farms/new` → `farms/:id/edit` → `farms/:id` の順で定義されており、`:id` の誤マッチなし（全マスタ共通）。
- **ワイルドカード位置**: `**` → NotFound は `pagesRoutes` 内にあり、`app.routes.ts` で最後に spread されるため全ルートの後段で機能する。
- **未ログイン保存導線**: 結果画面の保存 → `/login?return_to=<結果URL>` → OAuth → ミラー済みシェルで復帰 → `consumePendingPublicPlanSave()` で自動保存。設計として成立（ただし H2 のエッジケースあり）。

---

## 対応優先順位の提案

1. ~~H1 + H2（ログイン復帰導線）~~ — **対応済み**（2026-08 受け入れ確認）
2. H3（公開情報の露出。sitemap 再生成 + バケットから内部ファイル削除）
3. M1（`/dashboard` レガシールートの方針決定 — 削除か実体化か）
4. M2、M4（UX/SEO 改善。独立に着手可能）
5. ~~M3（スクロール位置復元）~~ — **対応済み**（`app-router-features.ts`）
