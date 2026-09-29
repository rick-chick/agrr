# 仕様不具合 対応計画 索引

仕様不具合の洗い出し結果を課題ごとに分け、それぞれ対応計画を文書化したもの。**計画のみでコード変更は含まない**。根拠はコード読解による静的確認で、実行で再現していない項目は各文書に「未確認」と明記している。

各文書の構成は共通: 現状（file:line 根拠）→ 仕様の確定と選択肢 → 影響範囲 → 対応方針 → TDD 計画（RED テスト案）→ 実装ステップ → リスク → 受け入れ条件 → 依存。

| # | 文書 | 重大度 | 要点 |
|---|------|--------|------|
| 01 | [resource-limit-bypass](01-resource-limit-bypass.md) | 高 | Farm 4 / Crop 20 の上限が経路ごとにスコープ違い（組織/ユーザー）。plan-save が `organization_id` を書かず上限をすり抜ける |
| 02 | [contact-recaptcha](02-contact-recaptcha.md) | 高 | サーバーは reCAPTCHA 必須、フロントは token を送らず問い合わせが常に失敗。**Cloudflare Turnstile へ方針変更**（ファイル名は据え置き） |
| 03 | [api-key-scope-docs](03-api-key-scope-docs.md) | 高 | `getting-started.md` のスコープ記述が実装と逆。書き込みスコープ付与手段も無い |
| 04 | [api-key-query-auth](04-api-key-query-auth.md) | 中 | `?api_key=` は文書にあるが #1165 で意図的に削除済み。文書のみ更新漏れ |
| 05 | [fail-closed-critical](05-fail-closed-critical.md) | 高 | climate の progress 失敗が手計算 GDD の成功応答に化ける／entry-schedule の作物要件が `{}` で続行 |
| 06 | [fail-closed-suspected](06-fail-closed-suspected.md) | 中 | fail-closed 違反の疑い 8 項目の判定（確定/許容/要判断） |
| 07 | [frontend-error-contract](07-frontend-error-contract.md) | 中 | `error` / `errors` 形式の不一致、未翻訳エラー、Crop 上限 UI、i18n 欠落 |
| 08 | [openapi-gaps](08-openapi-gaps.md) | 中 | OpenAPI と実装の乖離（204/403/429/PUT/body 形式ほか） |
| 09 | [stale-design-docs](09-stale-design-docs.md) | 低〜中 | ADR-002・設計文書の陳腐化、docs のリンク切れ 20 件 |
| 10 | [authorization-consistency](10-authorization-consistency.md) | 中（D5 は最優先で要検証） | R0 違反、`private()` と `private_with_scope` の不整合、公開 Plan の扱い |
| 11 | [low-priority-misc](11-low-priority-misc.md) | 低 | route manifest、`farm_sizes` API 未使用、contact レスポンス型、未使用 i18n |

## 決定事項（ユーザー指示の反映）

ユーザーからの指示「組織、Cloudflare、する、厳格、統合、与えない」を、各課題の未決事項へ次のとおり対応づけた。**この対応づけは文脈からの解釈**であり、誤りがあれば該当文書の「0. 決定事項」を差し替える。

| 指示 | 解釈 | 反映先 |
|------|------|--------|
| 組織 | Farm/Crop 上限は**組織単位に統一**する（案 A）。ユーザー単位カウントは廃止し、plan-save も組織経由にする | 01（関連: 09 のクォータ文書） |
| Cloudflare、する | 問い合わせフォームの CAPTCHA は reCAPTCHA ではなく **Cloudflare Turnstile を採用する** | 02 |
| 厳格 | fail-closed を**厳格に適用**する。疑い項目（06）も許容せず、握りつぶし・代替値・代替アルゴリズムを残さない | 05, 06 |
| 統合 | フロントとサーバーのエラー契約を**単一形式に統合**する（`error` / `errors` の混在を解消） | 07（関連: 08） |
| 与えない | (a) API キーに**書き込みスコープを付与しない**（付与手段を作らない）、(b) 組織メンバーに Plan の**編集権限を与えない**（閲覧の扱いは第 2 回決定で「閲覧も許さない」に確定） | 03, 10 |

### 決定事項（第 2 回: 未決事項への回答）

ユーザー指示「複数所属はスコープアウト、移行する、削除、errors、閲覧も許さない」を、各文書の未決事項へ次のとおり対応づけた。**文脈からの解釈**であり、誤りがあれば該当文書の「0. 決定事項」を差し替える。

| 指示 | 解釈 | 反映先 |
|------|------|--------|
| 複数所属はスコープアウト | 複数組織に所属するユーザーの作成先組織の規則（U2）は本件の範囲外。上限判定は「所属が 1 組織（個人組織）」を前提にし、複数所属の扱いは別課題とする | 01（関連: 09） |
| 移行する | V15 以前に発行された既存 API キーの read+write を read のみへ**データ移行する**（03 の X2） | 03 |
| 削除 | 公式 MCP の `apply_crop_setup` ツールを**削除する**（03 の M-A）。スキル手順は UI 適用へ書き換える | 03 |
| errors | エラー契約の統合先を **`errors`（配列）に確定**する。前回の推奨（`error`）は採らない | 07（関連: 02, 08） |
| 閲覧も許さない | 組織メンバーに他メンバー所有 Plan の**閲覧も許さない**。Plan 配下は所有者（と admin の扱いは未決）のみ | 10（関連: 01） |

## 着手順の推奨

1. **10 の D5**（私有ルート `PATCH /api/v1/plans/field_cultivations/{id}` で公開 Plan の圃場栽培を更新できる疑い）を最初に RED テストで再現確認する。
2. **01**（仕様確定が 09 のクォータ文書修正・10 の組織スコープ方針に波及する）。
3. **05 → 06**（fail-closed。05 が 06 の一部項目の前提）。
4. **02**（reCAPTCHA の種別・キー発行はユーザー判断が先）。
5. **03 → 04**（同じ `getting-started.md` を編集するため 03 を先に）。
6. **07, 08**（08 の D-12 は 10 と調整）。
7. **09, 11**（文書・整理。09 のクォータ関連は 01 の決定後）。

## ユーザー判断が必要な主な事項（各文書の「仕様の確定」章に詳細）

- 01: （組織単位で確定、複数所属はスコープ外）複数メンバー組織の枠共有、`ARCHITECTURE.md` の文言更新先。
- 02: Turnstile のサイト登録・キー発行と Secret Manager 登録、ウィジェットモード、プライバシー表記、旧 `RECAPTCHA_SECRET_KEY` の撤去時期。
- 03: （付与しない・移行する・MCP ツール削除で確定）本番の既存キー件数確認と移行の実施承認、利用者への通知、OpenAPI write operation の `security` 上書き、MCP バージョン。
- 05: （厳格で確定）HTTP ステータスのコード値、作業記録で progress 不可のときの扱い、port 形状。
- 07: （`errors` 配列へ統合で確定）旧キー（`error`/`message`）削除の実施可否（外部 API キー利用者の依存確認）。
- 08: `error_code` を enum にするか、not found を 404 か 422 か。
- 10: （編集も閲覧も許さないで確定）admin の扱い、Farm/Crop の組織編集も縮小するか、縮小前の本番実績確認、ADR-002 更新と組織共有の再開条件。

## テスト実行に関する共通の制約（各文書で確認された事項）

- `agrr-server` / `agrr-adapters-sqlite` のインラインテストには `test-common` 上の専用入口が無く、CI も一部を実行していない。RED は原則ドメインテストと R4 契約テストに置く計画。
- `run-test-frontend.sh` の単一ファイル指定、および `node --test` 系テスト（route manifest 等）を `test-common` 経路で実行できるかは未確認。規約上の障害として扱う方針は各文書を参照。

## 更新履歴

- 決定事項（組織 / Cloudflare / 厳格 / 統合 / 与えない）を 01, 02, 03, 05, 06, 07, 10 に反映。
- 第 2 回決定（複数所属スコープ外 / 移行する / 削除 / errors / 閲覧も許さない）を 01, 03, 07, 10 に反映。07 の統合先は `error` から `errors` に変更したため、02 の `code` 提案（07 では `error_code` に読み替え）、08 の `Error` スキーマ、05 の失敗本文、09 のクォータ文書・ADR 更新への追随が未実施。06 §9 と 08, 09, 11 の一部記述は、この決定（特に 02 の reCAPTCHA→Turnstile）への追随が未実施。
