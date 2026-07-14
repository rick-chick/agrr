# 修正・GREEN 確認の実施内容（詳細）

本 SKILL のワークフロー（修正スキル）で行うことの詳細。**前置条件**: 調査スキル（error-investigation）が完了していること。原因ごとに RED が再現するテストが存在し、そのテストを実行して RED であることを確認済みであること。

## 1. ソースの修正

- **対象に応じたスキル**: 修正する箇所（コントローラ・Presenter・Gateway・Interactor 等）に応じて、該当スキルを読みその手順に従う。対象別スキル一覧は [.cursor/references/CODE_MODIFICATION_SKILLS.md](.cursor/references/CODE_MODIFICATION_SKILLS.md) を参照する。
- RED の原因を解消する最小限の修正を行う。

## 2. テスト実行 → GREEN の確認

- 該当テストを再実行する。
- **GREEN** になったらその原因は解決済みとする。
- **GREEN にならない**場合は、視野を広げて調査スキルの候補原因の洗い出しに戻り、別の候補やより広い範囲を検討する。

## 3. 再起動

フロント・サーバーいずれも再起動を行わなければ確認できない場合は、無条件に再起動する。
[restart-angular](../../restart-angular/SKILL.md) / [restart-rails](../../restart-rails/SKILL.md) を参照する。

