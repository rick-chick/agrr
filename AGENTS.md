# Project rules
## 変更がないのにテストを２度走らせない
- 可
1. cd /home/akishige/projects/agrr && scripts/run-rust-contract-tests.sh > ./tmp/{UUID}.log
2. grep|tail|head|... ./tmp/{UUID}.log
- 不可
1. cd /home/akishige/projects/agrr && scripts/run-rust-contract-tests.sh > 2>&1 | tails -20
2. cd /home/akishige/projects/agrr && scripts/run-rust-contract-tests.sh > 2>&1 | grep hoge

## Readツールの使用はレンジを絞ること
- 可
1. まず grep で該当箇所を特定 → 行番号を把握
2. read で offset/limit を指定して範囲限定で読み込み
- 不可
1. 範囲指定なしで read ツールの使用

## Git（エージェント禁止・常時）
- **禁止（ユーザー明示まで）**: `git checkout` / `git switch` / `git reset` / `git restore` / `git clean`、force push
- **可**: `git status` / `diff` / `log` / `show` / `add` / `commit`（依頼時）
- 詳細: `.cursor/rules/git-operational-constraints.mdc`（`alwaysApply: true`）

## アーキテクチャ
バグ調査、コードを開始する前に`ARCHITECTURE.md`を読む

## まとめて対応せず、タスクを分解すること
- 可
1. 複数の細かい実行可能タスク(50k以下のコンテキストで達成可能）に分解する
2. 分解されたタスクをtmpに消込可能形式にまとめる
  - 共通作業詳細
  - [ ] Task1 : 作業概要
  - [ ] TaskN : 作業概要
3. compactを行ってからTaskNの作業を行う
4. 完了後にtmpの消込を行い、作業概要をまとめる
  - 共通作業詳細
  - [x] Task1 : 作業概要 実施作業概要
  - [ ] TaskN : 作業概要

- 不可
1. 複数の細かいタスクをグループ分けしてグループごとにに作業を行う
2. タスク分解を行わずに、作業を開始する

## 改修は TDD（スキル必須）
- ソース・テストの変更は **RED → GREEN → REFACTOR**。手順: `.cursor/skills/tdd-on-edit/SKILL.md`、ルール: `.cursor/rules/tdd-on-edit.mdc`
- テスト実行は **test-common** のみ。バグは `error-investigation` → `error-fix-red-green`

## 改修したらテストとレビューをすること
- 可
1. 複数のタスクがある中で一つのタスクを終えたので関連するテストだけ行う
1. タスクを終えたので、@ARCHITECTURE.mdに参照し、レビューする
1. 全部のタスクが終わったとき、全体テストを行う
- 不可
1. 全部のタスクが終わったあとに、全体テストを行わない
