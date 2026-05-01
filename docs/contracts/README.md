# 契約ドキュメント一覧

フロント（Angular）とサーバー（Rails）間の API 契約。`docs/contracts/{feature}-contract.md` に配置。

**実装ステータス**: 契約 MD **25 件**の目視ベース概況（詳細は各契約のチェックリスト参照）。

| # | 契約 | ファイル | ステータス |
|---|------|----------|------------|
| 1 | 農場（Farm） | [farm-contract.md](farm-contract.md) | 実装済み |
| 2 | 作物（Crop） | [crop-contract.md](crop-contract.md) | 実装済み |
| 3 | 肥料（Fertilize） | [fertilize-contract.md](fertilize-contract.md) | 実装済み |
| 4 | 病害虫（Pest） | [pest-contract.md](pest-contract.md) | 実装済み |
| 5 | 農薬（Pesticide） | [pesticide-contract.md](pesticide-contract.md) | 実装済み |
| 6 | 農作業（Agricultural Task） | [agricultural-task-contract.md](agricultural-task-contract.md) | 実装済み |
| 7 | 相互作用ルール | [interaction-rule-contract.md](interaction-rule-contract.md) | 実装済み |
| 8 | ほ場（Field） | [field-contract.md](field-contract.md) | 実装済み |
| 9 | 栽培計画詳細読み込み | [plan-detail-load-contract.md](plan-detail-load-contract.md) | 実装済み |
| 10 | 無料作付け計画の保存 | [public-plan-save-contract.md](public-plan-save-contract.md) | 実装済み |
| 11 | 作物スケジュール（エントリ） | [entry-schedule-contract.md](entry-schedule-contract.md) | 実装中 |
| 12 | Crop Update（HTML） | [crop-update-html-contract.md](crop-update-html-contract.md) | 実装済み |
| 13 | 作物ステージ編集 | [crop-stage-edit-contract.md](crop-stage-edit-contract.md) | 実装済み |
| 14 | 公開プラン plan_id リセット | [public-plan-creation-plan-id-reset-contract.md](public-plan-creation-plan-id-reset-contract.md) | 実装済み |
| 15 | お問い合わせ | [contact-form-contract.md](contact-form-contract.md) | 実装済み |
| 16 | i18n 更新手順 | [i18n-update-contract.md](i18n-update-contract.md) | 運用 |
| 17 | GDD チャート | [gdd-chart-contract.md](gdd-chart-contract.md) | 実装済み |
| 18 | 計画削除（確認なし） | [plan-delete-no-confirm-contract.md](plan-delete-no-confirm-contract.md) | 実装済み |
| 19 | 計画削除 | [plan-delete-contract.md](plan-delete-contract.md) | 実装済み |
| 20 | 作物ステージ一覧 | [crop-stages-contract.md](crop-stages-contract.md) | 実装済み |
| 21 | 管理農場一覧修正 | [admin-farm-list-fix-contract.md](admin-farm-list-fix-contract.md) | 実装済み |
| 22 | 農作業参照フラグ更新 | [agricultural-task-update-reference-flag-contract.md](agricultural-task-update-reference-flag-contract.md) | 実装済み |
| 23 | 私有プラン作成 | [private-plan-create-contract.md](private-plan-create-contract.md) | 実装済み |
| 24 | 栽培計画初期化・多圃場最適化（allocate） | [cultivation-plan-optimization-contract.md](cultivation-plan-optimization-contract.md) | 実装済み |
| 25 | 農場一覧（HTML） | [farm-list-html-contract.md](farm-list-html-contract.md) | 実装済み |

## 順次対応の進め方

1. **契約を参照して実装**  
   各 `{feature}-contract.md` の「フロント UseCase 一覧」「API 一覧」「共有 DTO」に従う。

2. **サーバー側 Clean Architecture 化**  
   各契約および `docs/adr/0001-clean-architecture-all-domains.md` に沿い、Interactor / Presenter / Gateway で実装する。

3. **実装チェックリスト**  
   各契約の「実装チェックリスト」を完了時に照合する。

4. **推奨順（マスタ）**  
   上表 1〜8 の順で契約準拠を確認してもよい。
