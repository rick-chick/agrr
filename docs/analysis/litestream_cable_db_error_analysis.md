# Litestream Cable Database エラー分析

## エラーメッセージ
```
level=ERROR msg="sync error" db=/tmp/production_cable.sqlite3 
error="checkpoint: mode=PASSIVE err=release read lock: no such table: _litestream_seq"
```

## エラーの詳細

### 発生タイミング
- Litestreamが既に実行中で、同期処理（sync）を行っている時
- チェックポイント（checkpoint）を実行しようとした時
- パッシブモード（PASSIVE）でのチェックポイント処理中

### 問題の本質
`_litestream_seq`テーブルが存在しない状態で、Litestreamがチェックポイントを実行しようとしている。

## 根本原因の仮説

### 仮説1: データベースファイルが存在するが、Litestreamがまだ初期化していない

**シナリオ:**
1. `litestream restore`が失敗（レプリカが存在しない）
2. Railsマイグレーション（`db:migrate:cable`）が実行され、データベースファイルが新規作成される
3. この新規作成されたデータベースファイルには`_litestream_seq`テーブルが存在しない
4. Litestream replicationが開始される
5. Litestreamが既存のデータベースファイルを見つけて、レプリケーションを開始しようとする
6. チェックポイント処理時に`_litestream_seq`テーブルが見つからずエラー

**問題点:**
- マイグレーションで作成されたデータベースファイルは、Litestreamの管理下にない
- Litestreamは既存のデータベースファイルに対して自動的に`_litestream_seq`テーブルを作成するとは限らない
- データベースファイルが存在しても、Litestreamが適切に初期化されていない可能性がある

### 仮説2: タイミングの問題（修正前のスクリプト）

**修正前の実行順序:**
1. Phase 1: メインデータベースの復元とマイグレーション（同期的）
2. Phase 2: バックグラウンドでqueue/cache/cableデータベースの復元とマイグレーションを開始
3. **Phase 3: すぐにLitestream replicationを開始** ← 問題の可能性
4. その後、queue/cache/cableデータベースのマイグレーション完了を待機

**問題点:**
- Litestream replicationが開始される時点で、cableデータベースの復元とマイグレーションがまだ完了していない可能性がある
- しかし、エラーメッセージは「sync error」であり、これはLitestreamが既に実行中であることを示している
- つまり、データベースファイルが存在するが、Litestreamが適切に初期化されていない状態

## 修正内容

### 修正後の実行順序
1. Phase 1: メインデータベースの復元とマイグレーション（同期的）
2. Phase 2: バックグラウンドでqueue/cache/cableデータベースの復元とマイグレーションを開始
3. Phase 3:
   - Step 3.1: queue/cache/cableデータベースのマイグレーション完了を待機
   - Step 3.2: すべてのデータベースファイルの存在確認
   - **Step 3.3: Litestream replication開始（すべてのデータベースが準備できた後）**
   - Step 3.4: Solid Queue worker起動
   - Step 3.5: Railsサーバー起動

### 修正の効果

**改善点:**
- Litestream開始前に、すべてのデータベース（cableを含む）の復元とマイグレーションが完了するのを待つ
- データベースファイルが存在することを確認してからLitestreamを開始

**しかし、根本的な問題は解決していない可能性:**
- マイグレーションで作成されたデータベースファイルには`_litestream_seq`テーブルがない
- Litestreamが既存のデータベースファイルに対して自動的にこのテーブルを作成するかどうかは不明
- データベースファイルが存在しても、Litestreamが適切に初期化されない可能性がある

## より適切な解決策の検討

### 解決策1: データベースファイルの存在チェックと削除
マイグレーションで作成されたデータベースファイルがLitestream管理下にない場合、削除してからLitestreamに作成させる

### 解決策2: Litestreamの初期化コマンドを実行
Litestreamにデータベースを初期化させるための明示的なコマンドを実行

### 解決策3: エラーハンドリングの改善
Litestreamのエラーをログに記録しつつ、アプリケーションの起動を継続（cableデータベースはオプショナルな場合）

## 検証が必要なポイント

1. **Litestreamの動作確認:**
   - 既存のデータベースファイルに対して、Litestreamが自動的に`_litestream_seq`テーブルを作成するか
   - 新規作成されたデータベースファイルに対して、Litestreamがどのように動作するか

2. **エラーの再現:**
   - 修正後のスクリプトで、同じエラーが発生するかどうか
   - エラーが発生する条件（データベースファイルの状態、タイミングなど）

3. **ログの確認:**
   - Litestreamのログを詳細に確認し、データベースファイルの状態や初期化のタイミングを把握

## 結論

現在の修正は、タイミングの問題を解決する可能性があるが、根本的な問題（データベースファイルがLitestream管理下にない）を完全に解決するとは限らない。

より確実な解決策としては、データベースファイルがLitestream管理下にあることを確認するか、Litestreamが適切に初期化されることを保証する必要がある。


