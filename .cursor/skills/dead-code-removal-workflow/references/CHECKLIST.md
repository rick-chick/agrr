# デッドコード削除 — 探索順・コマンド・完了チェック

## 探索の推奨順（目安）

1. シンボル名の **全リポジトリ横断**（下記 `rg`）
2. **ルート** → **ジョブ/キュー設定** → **initializer**
3. **`lib/` 全体**（ドメイン・ゲートウェイ・Rake） / `scripts` / CI
4. **フロント**（Angular + ルート `app/javascript`）
5. **docs / automation**（削除後の矛盾確認）

## `rg` 例

`YourClass`、`your_method`、`YourJob` を置換する。

```bash
# 1) 広く当てる（vendor / node_modules 除外）
rg -n 'YourClass' --glob '!**/vendor/**' --glob '!**/node_modules/**'

# 2) メソッド（定義と呼び出しを文脈で区別）
rg -n '\byour_method\b' --glob '*.rb'

# 3) 特定ジョブの列挙・エンキュー
rg -n 'YourJob' --glob '*.rb'
rg -n 'perform_later|perform_now' --glob '*.rb' | rg 'YourJob'

# 4) 動的解決
rg -n 'constantize|safe_constantize|const_get|qualified_const_get' --glob '*.rb'
rg -n 'public_send|__send__|\.send\(' --glob '*.rb'

# 5) ルート
rg -n 'YourController' config/routes.rb

# 6) 設定・lib 全体・タスク・CI（lib は domain / adapters / presenters / tasks を含む）
rg -n 'YourClass' config/ lib/ scripts/ .github/ 2>/dev/null || true

# 7) フロント
rg -n 'YourSymbol|your-file\.component' frontend/src --glob '*.{ts,html}'
rg -n 'YourModule' app/javascript

# 8) 削除予定パスの残骸
rg -n 'path/to/deleted' docs/ automation/
```

## Ruby — 静的探索の補完

`rg` / `debride` だけで落ちる未到達の列挙手順は **[ruby-unreferenced-methods.md](ruby-unreferenced-methods.md)**。

## 判定メモ

| 状況 | 扱い |
|------|------|
| 定義以外に参照なし（設定・ルート・動的経路・成果物も確認済み） | デッド候補（強い） |
| コメント・CHANGELOG・「削除済み」記述のみ | デッド根拠にしない |
| Job がテスト・チェーン・設定のいずれにも無い | デッド候補（強い） |
| `package.json` のみに存在し import 無し | **未使用依存**（コードデッドとは別） |
| ドキュメントだけが「実装済み」と言っている | 陳腐化 → 修正 or 削除 |

## 完了前チェック

- [ ] Phase A の探索範囲を踏み抜いていない
- [ ] 動的経路（`constantize` / `send` / ジョブ `chain`）を確認した
- [ ] `ARCHITECTURE.md` と該当テストの記述と矛盾する虚偽・陳腐リンクを残していない
- [ ] 無関係ファイルをコミットに含めていない
- [ ] `run-test-rails.sh` **全体**が GREEN
- [ ] npm 変更時は `frontend/package-lock.json` 更新済み
- [ ] test-slow-detection を実施した
