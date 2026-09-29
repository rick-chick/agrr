# 仕様不具合 対応計画 索引

仕様不具合の洗い出し結果を課題ごとに分け、それぞれ対応計画を文書化したもの。**計画のみでコード変更は含まない**。根拠はコード読解による静的確認で、実行で再現していない項目は各文書に「未確認」と明記している。

各文書の構成は共通: 現状（file:line 根拠）→ 仕様の確定と選択肢 → 影響範囲 → 対応方針 → TDD 計画（RED テスト案）→ 実装ステップ → リスク → 受け入れ条件 → 依存。

| # | 文書 | 重大度 | 要点 |
|---|------|--------|------|
| 01 | [resource-limit-bypass](01-resource-limit-bypass.md) | 高 | Farm 4 / Crop 20 の上限が経路ごとにスコープ違い（組織/ユーザー）。plan-save が `organization_id` を書かず上限をすり抜ける |
| 02 | [contact-recaptcha](02-contact-recaptcha.md) | 高 | サーバーは reCAPTCHA 必須、フロントは token を送らず問い合わせが常に失敗 |
| 03 | [api-key-scope-docs](03-api-key-scope-docs.md) | 高 | `getting-started.md` のスコープ記述が実装と逆。書き込みスコープ付与手段も無い |
| 04 | [api-key-query-auth](04-api-key-query-auth.md) | 中 | `?api_key=` は文書にあるが #1165 で意図的に削除済み。文書のみ更新漏れ |
| 05 | [fail-closed-critical](05-fail-closed-critical.md) | 高 | climate の progress 失敗が手計算 GDD の成功応答に化ける／entry-schedule の作物要件が `{}` で続行 |
| 06 | [fail-closed-suspected](06-fail-closed-suspected.md) | 中 | fail-closed 違反の疑い 8 項目の判定（確定/許容/要判断） |
| 07 | [frontend-error-contract](07-frontend-error-contract.md) | 中 | `error` / `errors` 形式の不一致、未翻訳エラー、Crop 上限 UI、i18n 欠落 |
| 08 | [openapi-gaps](08-openapi-gaps.md) | 中 | OpenAPI と実装の乖離（204/403/429/PUT/body 形式ほか） |
| 09 | [stale-design-docs](09-stale-design-docs.md) | 低〜中 | ADR-002・設計文書の陳腐化、docs のリンク切れ 20 件 |
| 10 | [authorization-consistency](10-authorization-consistency.md) | 中（D5 は最優先で要検証） | R0 違反、`private()` と `private_with_scope` の不整合、公開 Plan の扱い |
| 11 | [low-priority-misc](11-low-priority-misc.md) | 低 | route manifest、`farm_sizes` API 未使用、contact レスポンス型、未使用 i18n |

## 着手順の推奨

1. **10 の D5**（私有ルート `PATCH /api/v1/plans/field_cultivations/{id}` で公開 Plan の圃場栽培を更新できる疑い）を最初に RED テストで再現確認する。
2. **01**（仕様確定が 09 のクォータ文書修正・10 の組織スコープ方針に波及する）。
3. **05 → 06**（fail-closed。05 が 06 の一部項目の前提）。
4. **02**（reCAPTCHA の種別・キー発行はユーザー判断が先）。
5. **03 → 04**（同じ `getting-started.md` を編集するため 03 を先に）。
6. **07, 08**（08 の D-12 は 10 と調整）。
7. **09, 11**（文書・整理。09 のクォータ関連は 01 の決定後）。

## ユーザー判断が必要な主な事項（各文書の「仕様の確定」章に詳細）

- 01: 上限のスコープを組織単位に統一するか、ユーザー単位にするか。複数メンバー組織の枠共有、複数所属時の作成先。
- 02: reCAPTCHA の種別、キー発行と Secret Manager 登録、プライバシー表記。
- 03: 書き込みスコープの付与手段を提供するか。再生成で read のみに降格する挙動は意図か。
- 05: climate 失敗時の HTTP ステータス、`progress_records` 0 件の扱い。
- 07: サーバー側でエラー形式を統一するか、フロントが両形式を許容するか。
- 08: `error_code` を enum にするか、not found を 404 か 422 か。
- 10: 組織メンバーへ Plan 編集権限まで許すか。undo 認可の削除か組織対応か。

## テスト実行に関する共通の制約（各文書で確認された事項）

- `agrr-server` / `agrr-adapters-sqlite` のインラインテストには `test-common` 上の専用入口が無く、CI も一部を実行していない。RED は原則ドメインテストと R4 契約テストに置く計画。
- `run-test-frontend.sh` の単一ファイル指定、および `node --test` 系テスト（route manifest 等）を `test-common` 経路で実行できるかは未確認。規約上の障害として扱う方針は各文書を参照。
