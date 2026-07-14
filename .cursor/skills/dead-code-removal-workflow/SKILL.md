---
name: dead-code-removal-workflow
description: Verifies reachability across app, config, tasks, CI, docs, and frontend entrypoints; removes only repo-confirmed dead code and unused dependencies; consolidates tests and docs; stages unrelated git changes separately. Use when the user names this skill or asks for デッドコード, dead code removal, unused jobs, unused npm packages, or 到達可能性の検証 in the agrr repository.
disable-model-invocation: true
---

# デッドコード削除ワークフロー（AGRR）

## 適用

- ユーザーが **スキル名を明示**したとき、または **デッドコードの検証・削除・テスト/ドキュメント整理**を依頼したときに従う。
- 自動起動はしない（`disable-model-invocation: true`）。

## 目的

- リポジトリ内で **到達不能**と裏付けられたコード・依存だけを削る。
- 削除に伴い **テストの重複解消**・**ドキュメント/成果物の事実矛盾の除去**まで一貫させる。

## やらないこと（スコープ外）

- **`rg` の一致/不一致だけ**での違反判定やデッド断定（CA の禁止番号照合は別スキル）。
- **フルリポの未使用ファイル網羅**（knip 相当）は、依頼が無い限り必須にしない。依存パッケージと「到達不能モジュール」は区別する。
- **アーキ逸脱の便宜実装**でデッドを埋める（`ARCHITECTURE.md`・`no-convenience-tech-debt` に反する寄せ戻しは禁止）。

## 手順（フェーズ）

### Phase A — 到達可能性（広め・意味読み）

1. **探索範囲**: `app/` に限らず `config/`、**`lib/` 全体**（`lib/domain`・`lib/adapters`・`lib/presenters`・`lib/tasks/*.rake` など）、`db/`（コメントは参考）、`docs/`、`automation/`、`scripts/`、`.github/**` を含める。`lib/tasks` だけに絞る理由はない（Rake 以外の主参照は `lib/` 側に多い）。
2. **Ruby**: クラス/モジュール/定数/メソッド名の出現を追い、**定義・コメント・別シンボル**を切り分ける。
3. **動的経路**: `constantize` / `safe_constantize` / `const_get` / `qualified_const_get` / `send` / `public_send` / `__send__`、ジョブ `chain` の `class` 文字列、環境変数や initializer でのクラス名切替。
4. **ジョブ**: `perform_later` / `perform_now` / チェーン・定期実行設定（例: `config/recurring.yml`）への記載。
5. **HTTP 境界**: `config/routes.rb` の `to:` / `controller:` / `action:`。
6. **フック**: Mailer / Preview / `app/channels`。
7. **フロント**: Angular の `import`・ルート `loadChildren`・`standalone` の `imports`；ルートの `app/javascript/**` と `package.json` の esbuild エントリ。
8. **成果物**: 削除予定パスが契約・手順・バグ JSON に **現行コードとして**残っていないか。
9. **Ruby 補完（検出落ち）**: `rg` や `debride app lib config` だけでは落ちる **ポートと実装の同名・`module_function` の片系・未到達 private・未定義定数参照** を、[references/ruby-unreferenced-methods.md](references/ruby-unreferenced-methods.md) の手順で列挙する。

コマンド例・探索の順番メモ: [references/CHECKLIST.md](references/CHECKLIST.md)

### Phase B — 限界（リポジトリ外）

- 本番コンソール・別リポジトリ・ホスト固有スクリプトのみからの呼び出しは **このリポジトリだけでは否定不可**。運用リスクがあるときはユーザー確認（規約上の障害としてよい）。

### Phase C — 削除・置換

- **コード**: 到達不能が確定したもののみ削除。
- **テスト**: 「存在検査のみ」は削除か振る舞いへ。重複ファイルは **不足シナリオを本体テストへ移してから** 削除。誤解名はリネームも可。
- **ドキュメント**: 虚偽の「実装済み」は履歴注記か削除。陳腐化専用ドキュメントは削除し **被リンクを外す**。`ARCHITECTURE.md` と該当テストの記述と矛盾させない。
- **JSON 等**: 削除したファイルパスを「関連コード」に残さない。

### Phase D — 依存とロック

- `frontend` の npm 依存を削ったら **`frontend` で `npm install`** し `package-lock.json` を更新する。

### Phase E — 検証（このリポジトリ）

- Rails: **`.cursor/skills/test-common/scripts/run-test-rails.sh` を引数なしで全体実行**（部分実行は SimpleCov `minimum_coverage` で失敗しうる）。
- 続けて **test-slow-detection** スキルに従う。

### Phase F — コミット

- `git status` に無関係変更があるときは **関連パスのみ** `git add`。
- メッセージに削除理由の要約を書く。
- `git push` はユーザー明示時のみ。

## アンチパターン

- ヒット数ゼロ＝デッド、の **機械判定だけ**で削除する。
- 部分テストが通った時点で **全体成功を断定**する。
- 別件と混ぜて **`git add -A`** する。

## 参照

- [references/CHECKLIST.md](references/CHECKLIST.md) — `rg` 例・完了前チェック
- [references/ruby-unreferenced-methods.md](references/ruby-unreferenced-methods.md) — Ruby で静的探索が落ちる未到達の補完
- テスト実行の正: [test-common/SKILL.md](../test-common/SKILL.md)
- アーキ: リポジトリルートの `ARCHITECTURE.md`
