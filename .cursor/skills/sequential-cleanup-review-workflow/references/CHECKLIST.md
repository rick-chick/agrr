# 順次クリーンアップ・レビュー — チェックリスト

## 修正単位の進捗（コピーして使う）

```
修正単位: <名前（例: crop delete API presenter）>
マニフェスト: tmp/cleanup-unit-<slug>.md  （collect-modification-scope.sh で生成）
触れた層: <例: presenter-server, interactor-test-server>

- [ ] Step 0 マニフェスト・スコープ確定
- [ ] 改修 RED→GREEN 済み（tdd-on-edit）
- [ ] A デッドコード（A1 調査表 → ゲート → A2 実施）
- [ ] B 責務外テスト（B1 調査表 → ゲート → B2 実施 → B3 test-common）
- [ ] C 責務外コード（C1 調査表 → ゲート → C2 実施 → C3 test-common）
- [ ] D レビュー（D1 ARCHITECTURE 表 → ゲート → D2 全体 test-common + test-slow-detection）
- [ ] 残課題 backlog 更新（`tmp/cleanup-backlog-<parent-slug>.md`）
- [ ] 外側ループ: backlog pending 0 まで pop → TDD → 内側 cleanup
- [ ] 次の修正単位へ
```

エージェント実行時の委譲・ゲート詳細: [AGENT_ORCHESTRATION.md](AGENT_ORCHESTRATION.md)

## 修正単位マニフェスト（Step 0）

```bash
.cursor/skills/sequential-cleanup-review-workflow/scripts/collect-modification-scope.sh \
  --unit-name "<修正単位名>"
```

各 Step 完了後、マニフェストの進捗チェックと `## Step X` 節を更新する。**D 完了前に次の修正単位へ進まない。**

## ステップゲート（オーケストレーター用）

| Step | 次へ進む条件 |
|------|----------------|
| 0 | `tmp/cleanup-unit-*.md` が存在しスコープ一覧を確認済み |
| A1→A2 | 調査表の全行に「判定」列がある。`要確認` が 0 件（またはユーザー明示でスキップ） |
| A→B | マニフェスト `## Step A` に削除一覧 or「削除なし」と test-common 結果 |
| B1→B2 | 全 spec 行に「扱い」列。`移動` には移動先パス |
| B→C | マニフェスト `## Step B` 更新済み・関連 spec GREEN |
| C1→C2 | 全実装行に「扱い」列 |
| C→D | マニフェスト `## Step C` 更新済み・関連テスト GREEN |
| D1→D2 | TSV に D1 候補 **すべて** 記載 → `d-review-validate.sh` → ingest（[MECHANICAL_OUTER_LOOP.md](MECHANICAL_OUTER_LOOP.md)） |
| D→外側 | ingest 済み backlog を handoff で消化（[DUAL_LOOP.md](DUAL_LOOP.md)） |
| 外側→次単位 | backlog `pending` 0・直近 D 残課題 0・全体 test-common GREEN・test-slow-detection 実施済み |

## B — テスト: 移動 vs セーフ削除

```
そのテストは正しい層の spec か？
├─ NO → 振る舞いを正しい層の spec に移す（RED→GREEN）→ 元 spec をセーフ削除
└─ YES → その spec はまだ有効な振る舞いを表明しているか？
         ├─ NO（obsolete / 存在のみ）→ セーフ削除（根拠: 到達不能・重複）
         └─ YES → 他 spec と重複していないか？
                  ├─ YES → 統合してからセーフ削除
                  └─ NO → 維持
```

### 層の早見（フロント）

| 場所 | 主にテストするもの |
|------|-------------------|
| `*.usecase.spec.ts` | UseCase の分岐・Output Port への DTO・Fake Gateway 状態 |
| `*presenter*.spec.ts` | Presenter が View 状態へ写すこと（分岐の網羅は UseCase） |
| `*gateway*.spec.ts` | HTTP マッピング・エラー変換（ユースケース分岐は UseCase） |
| `*.component.spec.ts` | View バインディング・ユーザー操作の委譲（UseCase 分岐を網羅しない） |

### 層の早見（サーバー）

| 場所 | 主にテストするもの |
|------|-------------------|
| `test/domain/**` | Interactor / Entity の純粋な振る舞い |
| `test/adapters/**/presenters` | Presenter の JSON 形状 |
| `test/adapters/**/gateways` | 永続化・外部 I/O のマッピング |
| 契約 / R4 | HTTP 境界の観測可能な振る舞い |

詳細は各 `*-test-*` スキルと [`usecase-test-frontend`](../../usecase-test-frontend/SKILL.md) を参照。

## C — コード: 移動 vs セーフ削除

```
そのコードはファイルの層の責務か？（ARCHITECTURE.md）
├─ NO → 正しい層へ移動（tdd-on-edit）→ 旧参照を更新 → デッドになった旧コードは A へ
└─ YES → 変更で不要になったか？
         ├─ YES → A（デッドコード）でセーフ削除
         └─ NO → 維持
```

### Component に混ざりやすい責務外

| 混在 | 移動先 |
|------|--------|
| API 呼び出し・リトライ | Gateway + UseCase |
| 成功/失敗の分岐・バリデーション | UseCase |
| View 用の表示状態の組み立て | Presenter |
| モーダル開閉・debounce のみ | `shared-screen-only-component` |

## D — レビュー記録テンプレ（修正単位ごと）

```markdown
## レビュー: <修正単位名>

- 触れた層: ...
- ARCHITECTURE 照合: 問題なし / 要修正（層・条項）
- test-common: 個別 GREEN / 全体 GREEN
- test-slow-detection: 実施済み
- 残課題: なし / あり（id → `tmp/cleanup-backlog-<parent-slug>.md`）
- 外側スタック: pending N 件
- セーフ削除したもの: （ファイル・理由を 1 行ずつ）
- 移動したもの: （from → to）
```

## セーフ削除の最低根拠（いずれか必須）

1. **到達不能** — dead-code-removal-workflow Phase A で裏付け
2. **重複カバレッジ** — 残すテスト名と観測点を明示
3. **誤レイヤ** — 移動先 spec が同等以上の振る舞いを GREEN で表明済み
4. **obsolete** — 削除したルート・API・画面に紐づくのみ（契約・ルートの観測で確認）

根拠が「たぶん」だけのときは削除しない。調査を続ける。
