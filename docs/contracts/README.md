# 契約ドキュメント一覧

フロント（Angular）とサーバー（Rails）間の API 契約。feature-contract スキルに従い `docs/contracts/{feature}-contract.md` に配置。

## マスタ系契約（順次対応用）

| # | 契約 | ファイル | スコープ |
|---|------|----------|----------|
| 1 | 農場（Farm） | [farm-contract.md](farm-contract.md) | 農場 CRUD、農場詳細でのほ場一覧取得 |
| 2 | 作物（Crop） | [crop-contract.md](crop-contract.md) | 作物 CRUD |
| 3 | 肥料（Fertilize） | [fertilize-contract.md](fertilize-contract.md) | 肥料 CRUD |
| 4 | 病害虫（Pest） | [pest-contract.md](pest-contract.md) | 病害虫 CRUD |
| 5 | 農薬（Pesticide） | [pesticide-contract.md](pesticide-contract.md) | 農薬 CRUD |
| 6 | 農作業（Agricultural Task） | [agricultural-task-contract.md](agricultural-task-contract.md) | 農作業 CRUD |
| 7 | 相互作用ルール（Interaction Rule） | [interaction-rule-contract.md](interaction-rule-contract.md) | 相互作用ルール CRUD |
| 8 | ほ場（Field） | [field-contract.md](field-contract.md) | ほ場 CRUD（農場に紐づく） |

## その他

| 契約 | ファイル | 備考 |
|------|----------|------|
| 栽培計画詳細読み込み | [plan-detail-load-contract.md](plan-detail-load-contract.md) | 既存実装の契約サンプル |
| 無料作付け計画の保存 | [public-plan-save-contract.md](public-plan-save-contract.md) | 結果画面「保存」→ 個人計画にコピー（API・認証必須） |
| Crop Update（HTML） | [crop-update-html-contract.md](crop-update-html-contract.md) | 作物編集フォームで crop_stages_attributes / nutrients を Interactor 経由で反映（Rails 内部契約） |

## 順次対応の進め方

1. **契約を参照して実装**  
   各 `{feature}-contract.md` の「フロント UseCase 一覧」「API 一覧」「共有 DTO」に従い、usecase-frontend / usecase-server / gateway-frontend / gateway-server / controller-server / controller-frontend / presenter-frontend / presenter-server の各スキルで実装する。

2. **サーバー側 Clean Architecture 化**  
   サーバーは [MASTER_SERVER_CLEAN_ARCHITECTURE_TODO.md](../implementation/MASTER_SERVER_CLEAN_ARCHITECTURE_TODO.md) に従い、契約の API を Interactor / Presenter / View / Gateway で実装する。契約の Request/Response スキーマがそのまま DTO・Entity の基準になる。

3. **実装チェックリスト**  
   各契約の「6. 実装チェックリスト」を完了時に照合する。

4. **推奨順**  
   上表の 1 → 8 の順で 1 リソースずつ契約準拠（＋サーバーはスキル準拠）にしてもよい。farm から始め、次に crop / fertilize / pest と進め、最後に field（農場詳細内）とする。
