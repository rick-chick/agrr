# CA Violations Backlog

最終通し走査: 2026-05-06（禁止 1〜30 の全文は完了していない。空 backlog の裏取りで `FarmsController#index` の JSON を是正）

## 修正単位

- [ ] **FarmsController HTML JSON（show / update）** — ARCHITECTURE.md **Application edge and tests → 4** @ `app/controllers/farms_controller.rb`
  - `show` の `format.json` が `render json: @farm`（インタラクター経由の取得・DTO ではない）
  - `update` の `format.json` が `@farm.update(farm_params)` をコントローラで実行

## スキャン補足

- 2026-05-06: `GET /farms` の JSON は `FarmListInteractor` + `Presenters::Html::Farm::FarmListJsonPresenter` に統合（コミットはメッセージ参照）。
