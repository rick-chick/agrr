# 順次クリーンアップ・レビュー — チェックリスト

## 修正単位の進捗（コピーして使う）

```
修正単位: <名前（例: crop delete API presenter）>
触れた層: <例: presenter-server, interactor-test-server>

- [ ] 改修 RED→GREEN 済み（tdd-on-edit）
- [ ] A デッドコード（触れた範囲）
- [ ] B 責務外テスト
- [ ] C 責務外コード
- [ ] D レビュー（ARCHITECTURE + test-common 全体 + test-slow-detection）
- [ ] 次の修正単位へ
```

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
- セーフ削除したもの: （ファイル・理由を 1 行ずつ）
- 移動したもの: （from → to）
```

## セーフ削除の最低根拠（いずれか必須）

1. **到達不能** — dead-code-removal-workflow Phase A で裏付け
2. **重複カバレッジ** — 残すテスト名と観測点を明示
3. **誤レイヤ** — 移動先 spec が同等以上の振る舞いを GREEN で表明済み
4. **obsolete** — 削除したルート・API・画面に紐づくのみ（契約・ルートの観測で確認）

根拠が「たぶん」だけのときは削除しない。調査を続ける。
