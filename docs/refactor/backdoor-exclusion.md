# Backdoor Controller リファクタ除外宣言

## 背景

`app/controllers/api/v1/backdoor/backdoor_controller.rb` は管理用 / デバッグ用の専用コントローラであり、本番のユーザー導線には乗らない。Cloud Run 内部からの diagnostics・データ削除・トランザクション操作・直接 SQL を行うため、本リポジトリの Clean Architecture リファクタ（Controller→Interactor / ドメイン非Rails化 計画）の対象から **明示的に除外** する。

## 除外内容

`api/v1/backdoor/backdoor_controller.rb` 内に存在する以下の AR / Rails パターンはリファクタ対象外:

- `::User.find` / `::CultivationPlan.find` / `::Farm.find` 等の AR 定数直叩き
- `ActiveRecord::Base.transaction` ブロック
- `::Model.delete_all` / `update_all` / `upsert_all` 等のバルク操作
- `rescue ActiveRecord::`* 例外捕捉
- 直接 SQL 操作（必要に応じ追加）

## 理由

1. backdoor は **debug 専用** で本番ユーザー操作フロー外。
2. Adapter 越しの操作は無価値（diagnostics は AR の挙動を直接観測したい）。
3. Interactor 化によりテストコストだけが膨らみ、本来のドメイン契約を歪める。

## 監査時の対応

- `t42-final-audit` での rg 監査において以下のパターンに `app/controllers/api/v1/backdoor` を **常に除外** すること:
  ```bash
  rg "::CultivationPlan|::Farm|::Crop|::Pest|::Pesticide|::Fertilize|::Field|::AgriculturalTask|::InteractionRule|::FieldCultivation|::TaskSchedule|::TaskScheduleItem|::CropTaskTemplate|::CropTaskScheduleBlueprint|::DeletionUndoEvent|::CropPest|::CropStage|::User" app/controllers --glob '!app/controllers/api/v1/backdoor/**'
  ```
- 同様に rescue / current_user.* / Gateway.default 監査も backdoor 配下を除外する。

## 改廃時のガード

backdoor controller を本番ユーザー操作で使う必要が出た場合、本ドキュメントを更新し、対応するドメイン Interactor を新設してから AR 操作を解消する。