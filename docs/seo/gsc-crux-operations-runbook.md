# GSC / CrUX / SEO ルーティング運用ランブック

**目的**: フロントエンド本番デプロイ後および定期運用で、Google Search Console（GSC）・Chrome UX Report（CrUX）・HTTP ルーティングを一貫して確認する手順をまとめる。  
**レビュー観点（チェックリスト）**: [`seo-review-perspectives.md`](./seo-review-perspectives.md) §13（計測・継続モニタリング）  
**正本スクリプト**: [`.cursor/skills/deploy-frontend/scripts/`](../../.cursor/skills/deploy-frontend/scripts/)（新規スクリプトは作らない）  
**関連 ADR**: [ADR-strangler-lb-url-map.md § SEO / クロール](../migration/app-rust-stack/ADR-strangler-lb-url-map.md#seo--クロール2026-06-09-追記)  
**デプロイ手順**: [deploy-frontend スキル](../../.cursor/skills/deploy-frontend/SKILL.md)

`sitemap.xml` はデプロイ時に `generate-sitemap.mjs` で自動生成される。GSC 再送信は**手動**（本 issue スコープ外で CI 自動化は任意 follow-up）。HTTP ルーティング検証は `frontend-deploy` workflow（master push の本番デプロイ成功後）で自動実行される（§2 参照）。

---

## 1. いつ実行するか（推奨頻度）

| 頻度 | 対象 | 主な作業 |
|------|------|----------|
| **デプロイ直後**（必須） | 本番 `agrr.net` | §2 機械検証 → §3 GSC sitemap 再送信 |
| **週次** | GSC | §4.1 カバレッジ・インデックス異常・アラート確認 |
| **月次** | Core Web Vitals（CWV） | §4.2 GSC CWV レポート + §5 PSI フィールドデータ（代表 URL） |
| **四半期** | フル監査 | §2〜§5 一式 + §6 チェックリスト + research 再ビルド要否（[vitepress-rebuild-checklist.md](./vitepress-rebuild-checklist.md)） |

---

## 2. デプロイ直後 — HTTP / ルーティング検証

**CI（推奨）**: master への push で `frontend-deploy` workflow が本番デプロイ成功後に自動実行する（`BASE_URL=https://agrr.net`）。失敗時は workflow が失敗する。

**手動**（ローカル・再検証）: プロジェクトルートで実行（デフォルト `BASE_URL=https://agrr.net`）:

```bash
.cursor/skills/deploy-frontend/scripts/verify-seo-routing.sh
```

### 2.1 スクリプトが確認する内容（要約）

| カテゴリ | 例 |
|----------|-----|
| SPA 公開ルート | `/`, `/about`, `/login`, `/public-plans/new`, results / optimizing（クエリ付き） |
| 静的 SEO | `robots.txt`, `sitemap.xml`（件数 ≥ 100、内部作業用パス非含有） |
| Research 静的 HTML | `/research/`、代表 `.html`、拡張子なし 404、内部テンプレート 404 |
| リダイレクト | `www` → apex、`/public_plans` → `/public-plans/new`、legacy `/us/about` 等 |

失敗時は [deploy-frontend スキル §トラブルシューティング](../../.cursor/skills/deploy-frontend/SKILL.md) と LB URL map（ADR 上記）を照合する。staging 確認は `BASE_URL=https://agrr-test.net`（該当環境がある場合）。

### 2.2 成功後 — GSC へ sitemap 再送信

初回のみ ADC に Search Console スコープが必要（[deploy-frontend § GSC 初回認証](../../.cursor/skills/deploy-frontend/SKILL.md)）:

```bash
gcloud auth application-default login \
  --scopes="openid,https://www.googleapis.com/auth/userinfo.email,https://www.googleapis.com/auth/cloud-platform,https://www.googleapis.com/auth/webmasters"
gcloud auth application-default set-quota-project agrr-475323
```

再送信:

```bash
.cursor/skills/deploy-frontend/scripts/submit-sitemap-gsc.sh
```

環境変数（通常はデフォルトで可）:

| 変数 | デフォルト |
|------|------------|
| `GSC_SITE_URL` | `sc-domain:agrr.net` |
| `GSC_SITEMAP_URL` | `https://agrr.net/sitemap.xml` |
| `GSC_QUOTA_PROJECT` | `agrr-475323` |

---

## 3. デプロイパイプラインとの関係

| 処理 | タイミング | スクリプト |
|------|------------|------------|
| sitemap 生成 | `gcp-frontend-deploy.sh` 内（ビルド前） | `generate-sitemap.mjs` |
| GCS 同期・CDN 無効化 | 同上 | `gcp-frontend-deploy.sh` |
| HTTP 検証 | **frontend-deploy CI**（master push 本番デプロイ後）+ 手動再検証可 | `verify-seo-routing.sh` |
| GSC 再送信 | **手動**（検証成功後） | `submit-sitemap-gsc.sh` |

本番デプロイコマンド:

```bash
.cursor/skills/deploy-frontend/scripts/gcp-frontend-deploy.sh deploy production
```

---

## 4. GSC 定期確認（週次・月次）

GSC プロパティ: **ドメイン** `agrr.net`（API では `sc-domain:agrr.net`）。

### 4.1 週次 — インデックスとカバレッジ

[Search Console](https://search.google.com/search-console) で確認:

1. **ページのインデックス登録** — エラー・除外の急増がないか
2. **サイトマップ** — `https://agrr.net/sitemap.xml` が「成功」、検出 URL 数が想定範囲か（`verify-seo-routing.sh` の件数と大きく乖離しないこと）
3. **手動による対策** — 新規の問題があれば issue 化

大きなデプロイ（research 同期・URL map 変更）後は週次に加え **§2 を即時** 実行する。

### 4.2 月次 — Core Web Vitals（CWV）

GSC → **エクスペリエンス** → **ウェブに関する主な指標**:

| 指標 | 注意点 |
|------|--------|
| LCP / INP / CLS | URL グループ単位。悪化グループは §5 の代表 URL で PSI を深掘り |
| モバイル vs デスクトップ | 公開 SPA はモバイル優先で確認 |

CrUX は**実ユーザーの 28 日集計**のため、デプロイ効果は数日〜数週間遅れて反映される。リリース直後の判定は PSI の**ラボデータ**を補助に使う。

---

## 5. PageSpeed Insights（PSI）— テンプレート別代表 URL

[PageSpeed Insights](https://pagespeed.web.dev/) で **フィールドデータ**（CrUX あり）と **ラボデータ**を確認する。テンプレートごとに代表 URL を固定し、月次比較する。

| テンプレート | 代表 URL | 備考 |
|--------------|----------|------|
| ホーム | `https://agrr.net/` | デフォルト meta・OG |
| 静的 About | `https://agrr.net/about` | SPA ミラー index |
| 公開プラン入口 | `https://agrr.net/public-plans/new` | 主要コンバージョン導線 |
| 認証 | `https://agrr.net/login` | インデックス対象外でも CWV 参考 |
| Research 索引 | `https://agrr.net/research/` | 静的 VitePress 出力 |
| Research 記事 | `https://agrr.net/research/research_reports/radish/03_pest_disease/major_pests.html` | `verify-seo-routing.sh` と同じ代表パス |

**運用メモ**:

- フィールドデータが「なし」の URL はトラフィック不足。ラボのみで regressions を検知する。
- `public-plans/results` / `optimizing` はクエリ依存のため、PSI では上表の固定 URL を優先する（ルーティング検証は `verify-seo-routing.sh` がクエリ付きでカバー）。
- research 大量更新後は記事 URL を 1 件追加サンプルしてもよい（作物・カテゴリが変わった場合）。

---

## 6. 四半期フル監査チェックリスト

- [ ] `verify-seo-routing.sh` が exit 0
- [ ] `submit-sitemap-gsc.sh` が HTTP 200/204（大きな URL 構造変更時）
- [ ] GSC サイトマップ・インデックスに未解決エラーがない
- [ ] GSC CWV で「不良」URL グループに新規急増がない
- [ ] §5 の全代表 URL を PSI で確認（フィールド + ラボ）
- [ ] `docs/seo/vitepress-rebuild-checklist.md` — research ソース変更があれば再ビルド・GCS 同期済み
- [ ] ADR の SEO 表（robots / sitemap pathRule、www、legacy redirect）と本番 map に差分がない

---

## 7. トラブルシューティング（早見）

| 症状 | 確認先 |
|------|--------|
| sitemap 件数不足 | `public/research/` の同期、`generate-sitemap-lib.mjs` の index 対象 |
| research 404 / 拡張子なし 404 | [vitepress-rebuild-checklist.md](./vitepress-rebuild-checklist.md)、LB `/research/*` rewrite |
| GSC API 403 | ADC スコープ・quota project（§2.2） |
| CWV 悪化のみ | フロントバンドルサイズ・画像・CDN キャッシュ（deploy の Cache-Control） |
| www / legacy URL | ADR pathRule、`verify-seo-routing.sh` の redirect 行 |

---

## 8. スコープ外（任意 follow-up）

- CrUX API による自動取得スクリプト
- GSC アラートの Slack 通知

必要なら別 issue で起票する（本ランブックは手動運用を正とする）。

---

## 参照

| リソース | パス |
|----------|------|
| SEO レビュー観点（§13 モニタリング） | [seo-review-perspectives.md](./seo-review-perspectives.md) |
| デプロイ・SEO スクリプト一覧 | [deploy-frontend/SKILL.md](../../.cursor/skills/deploy-frontend/SKILL.md) |
| Research 再ビルド | [vitepress-rebuild-checklist.md](./vitepress-rebuild-checklist.md) |
| LB / SEO ADR | [ADR-strangler-lb-url-map.md](../migration/app-rust-stack/ADR-strangler-lb-url-map.md) |
| sitemap 単体テスト | `node --test .cursor/skills/deploy-frontend/scripts/generate-sitemap.test.mjs` |
