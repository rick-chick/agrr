---
name: find-method-dead-code
description: Ruby メソッドレベルのデッドコード検出（.cursor/skills/find-method-dead-code/scripts/find-method-dead-code.py 実行 + LLM によるメソッド単位の個別判定）。ユーザーがメソッド単位でのデッドコード解析、テスト専用メソッドの特定、find-method-dead-code.py の実行を依頼したときに適用する。
disable-model-invocation: true
---

# メソッドレベル デッドコード検出（AGRR）

## 適用

- ユーザーが **`find-method-dead-code.py` の実行**、**メソッド単位のデッドコード解析**、**テスト専用メソッドの特定**を依頼したときに従う。
- `dead-code-removal-workflow` とは異なり、**メソッド単位**で個別に判定する。

## 手順（フェーズ）

### Phase 1 — スクリプト実行

```bash
cd /home/akishige/projects/agrr
python3 .cursor/skills/find-method-dead-code/scripts/find-method-dead-code.py
```

出力は TSV フォーマットで標準出力される。ファイルパスを指定するとファイルに出力される。

### Phase 2 — LLM によるメソッド単位の個別判定

スクリプトが検出した **各候補メソッド** について、LLM が個別に判定する。

#### 判定基準

| 状況 | 扱い |
|------|------|
| テスト専用で本番から呼ばれていない（`send`/`public_send`/動的経路も確認） | **デッド** — 削除候補 |
| テストからの参照のみだが、本番の `config/routes.rb` / ジョブ / initializer で間接的に使われる可能性あり | **要確認** — 追加調査が必要 |
| ポート宣言（`NotImplementedError` 等）のみで実装がテスト専用 | **ポート表面の冗長** — 削除候補 |
| `module_function` の一部メソッドがテスト専用、他は本番で使用 | **部分デッド** — メソッド名ごとに区別して判定 |
| テストヘルパー / モック用メソッドで実装に不要 | **テスト専用** — 削除しても本番に影響なし |

#### 判定手順

1. **メソッド名の文脈確認**: `def` の前後 20 行を読み、何をするメソッドか把握する
2. **呼び出し側の有無（ファイルを開く）**: `test/` 以外でそのメソッド名が呼ばれていないか確認
3. **動的経路の確認**: `send(:method_name)` / `public_send` / `constantize` / コールバック等で呼ばれていないか確認
4. **テストコードの参照**: テスト内でどのように使われているか確認（実装テスト用か、本番でも必要か）
5. **最終判定**: 上記を総合して「デッド」「要確認」「セーフ」のいずれかに分類

### Phase 3 — 結果の報告

各メソッドについて以下の情報を報告する:

```
[デッド / 要確認 / セーフ] file_path:line_number - method_name (class_context)
理由: <判定の根拠>
参考: テスト内での参照箇所（該当する場合）
```

### Phase 4 — 削除の実施（ユーザー指示時）

ユーザーが削除を指示した場合のみ、`dead-code-removal-workflow` スキルに従って削除を実施する。

## やらないこと

- **スクリプトの出力だけを信じて削除しない**。必ず LLM が個別に判定する。
- `dead-code-removal-workflow` の範囲を超えるファイル単位のデッドコード検出は行わない（そちらは別スキル）。
- 本番コンソール・別リポジトリのみからの呼び出しは **このリポジトリだけでは否定不可**。

## 参照

- [dead-code-removal-workflow/SKILL.md](../dead-code-removal-workflow/SKILL.md) — ファイル/モジュール単位のデッドコード削除
- [references/ruby-unreferenced-methods.md](../dead-code-removal-workflow/references/ruby-unreferenced-methods.md) — Ruby 静的探索の補完手順
