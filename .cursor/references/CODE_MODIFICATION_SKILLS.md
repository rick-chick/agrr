# コード修正時の対象別スキル一覧

コードを修正するさいは、**修正対象（場所・種類）に応じて該当スキルを読み、そのスキルに従う**。自分の流れで実装やテストを書かず、対象に合ったスキルを開いて手順に従う。

## 使い方

1. **TDD**: 改修のたびに [`tdd-on-edit` スキル](../skills/tdd-on-edit/SKILL.md)（ルール: [`tdd-on-edit.mdc`](../rules/tdd-on-edit.mdc)）— 先に RED、`test-common` で確認してから実装
2. 修正対象が下のどれに当たるか確認する（ファイルパス・クラス名・責務で判断）
3. 該当行の **実装スキル** または **テストスキル** を開く（`.cursor/skills/<name>/SKILL.md`）
4. スキルのワークフロー・原則に従って修正する

## Clean Architecture の規律（新規・改修共通）

**境界に触れる変更**では **`ARCHITECTURE.md`** の **`## What we require`** と **`## Prohibited practices`（1–30）** を、**触れる層だけ**照合する（番号だけに偏らない）。**親**は実装スキルに加え **実装後の Clean Architecture チェック** を省略しない（範囲・手順は [`agent-conventions.mdc`](../rules/agent-conventions.mdc) 用語表、ループは [ワークフロー SKILL](../skills/clean-architecture-violation-fix-workflow/SKILL.md)）。**新規・改修・単発を問わず**外側ループ（セクション0・セクション6）と内側ループは同一ワークフロー。機能一式の Phase 束ねは **`feature-orchestrator.mdc`**。

## 対象別一覧

### サーバー（Rails）

| 修正対象（場所・種類） | 実装スキル | テストスキル |
|------------------------|------------|--------------|
| API コントローラ（`app/controllers/api/`） | controller-server | controller-test-server |
| Presenter（adapter 層、Output Port 実装） | presenter-server | presenter-test-server |
| Gateway 実装（adapter 層、Repository） | gateway-server | gateway-test-server |
| Interactor・Input/Output Port・Gateway Interface・Entity（`lib/domain/`） | usecase-server | interactor-test-server（Interactor）/ entity-test-server（Entity） |

### フロント（Angular）

| 修正対象（場所・種類） | 実装スキル | テストスキル |
|------------------------|------------|--------------|
| Component（Controller・View  interface）（`frontend/src/app/components/`） | controller-frontend | controller-test-frontend |
| Presenter（adapter 層、Output Port 実装） | presenter-frontend | presenter-test-frontend |
| Gateway（API クライアント）（`frontend/src/app/adapters/`） | gateway-frontend | gateway-test-frontend |
| UseCase・Gateway Interface・Presenter Interface（`frontend/src/app/usecase/` 等） | usecase-frontend | usecase-test-frontend |
| Domain 型・Entity（`frontend/src/app/domain/`） | （usecase-frontend の文脈で定義） | entity-test-frontend |

### その他（対象別）

| 修正対象 | スキル |
|----------|--------|
| UI デザイン・Angular Material・テーマ・HTML 構造 | design-angular-material |
| 画面専用ロジックの分離（開閉・ホバー・タイマー等） | shared-screen-only-component |
| 契約（API 仕様）の作成・修正 | feature-contract |
| フロントのテストフレームワーク（Jest / Vitest 方針） | [TEST_FRAMEWORK.md](TEST_FRAMEWORK.md) |
| 改修全般の TDD（バグ以外: RED→GREEN。バグは下段） | tdd-on-edit |
| エラー調査・バグ修正の手順（調査→RED 検証は error-investigation、修正→GREEN は error-fix-red-green） | error-investigation / error-fix-red-green |
| Phase 2/3 の cursor-agent 実行 | run-phase-agent |
| Rails サーバー再起動 | restart-rails |
| Angular サーバー再起動 | restart-angular |
| Clean Architecture（実装前の確認・セクション2 相当・セクション4・test-common・セクション0〜6 外側ループ） | clean-architecture-violation-fix-workflow（**新規実装・機能追加（内側ループの前提）** を含む同一 SKILL） |
| 修正単位ごとのデッド削除・責務外テスト/コード整理・順次レビュー | sequential-cleanup-review-workflow |

## スキル一覧（名前・用途）

| スキル名 | 用途 |
|----------|------|
| controller-server | Rails API コントローラ実装（DTO・View・Interactor 委譲） |
| controller-test-server | Rails コントローラの結合/リクエストテスト |
| presenter-server | Rails Presenter 実装（Output Port・View 注入） |
| presenter-test-server | Rails Presenter のユニットテスト |
| gateway-server | Rails Gateway 実装（Repository） |
| gateway-test-server | Rails Gateway のユニットテスト |
| usecase-server | Rails usecase 層（Interactor・Port・Gateway Interface・Entity） |
| interactor-test-server | Rails Interactor のユニットテスト |
| entity-test-server | Rails Entity（lib/domain）のユニットテスト |
| controller-frontend | Angular Component（Controller・View）実装 |
| controller-test-frontend | Angular Component のユニットテスト |
| presenter-frontend | Angular Presenter 実装 |
| presenter-test-frontend | Angular Presenter のユニットテスト |
| gateway-frontend | Angular Gateway（API クライアント）実装 |
| gateway-test-frontend | Angular Gateway のユニットテスト |
| usecase-frontend | Angular UseCase・Port・Gateway Interface 実装 |
| usecase-test-frontend | Angular UseCase のユニットテスト |
| entity-test-frontend | Angular domain 型・Entity のユニットテスト（Vitest 使用） |
| design-angular-material | UI デザイン・Material・テーマ・アクセシビリティ |
| shared-screen-only-component | 画面専用ロジックの分離 |
| feature-contract | API 契約ドキュメントの作成 |
| tdd-on-edit | 改修・新規の TDD（RED→GREEN→REFACTOR。test-common 必須） |
| error-investigation | エラー調査・RED による検証まで（原因の特定と失敗テストで検証） |
| error-fix-red-green | RED 確認済みを前提にソース修正→GREEN 確認 |
| run-phase-agent | Phase 2/3 のサブエージェント起動 |
| restart-rails | Rails サーバー再起動 |
| restart-angular | Angular サーバー再起動 |
| clean-architecture-violation-fix-workflow | ARCHITECTURE 境界の仕上げ（**新規・削減とも**セクション0〜6・ゲート・test-common。同一ワークフロー） |
| sequential-cleanup-review-workflow | 修正単位ごとにデッド削除・責務外テスト/コードの移動またはセーフ削除・レビュー（後片付けの一括化禁止） |

## 参照元

- **error-fix-red-green** のステップ 1「ソースの修正」: 修正時はこの一覧に従い該当スキルを読んで従う。
- **clean-architecture-violation-fix-workflow**: **新規・改修・削減**とも **セクション0〜セクション6**・ゲート・test-common を省略しない。
- **use-skills-on-edit.mdc**: コード修正時は対象に応じたスキルを使用する。一覧は本ドキュメントを参照。
