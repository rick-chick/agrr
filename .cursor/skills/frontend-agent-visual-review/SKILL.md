---
name: frontend-agent-visual-review
description: >-
  AGRR Angular の route-manifest 由来 PNG（e2e/agent-review/out）を、route-to-png.md 1 行ずつ
  ビジュアルレビューし、tmp/agent-review/visual-review.json に書き出す。
  CSS トークン列挙は含めない（npm run audit:css-tokens を正とする）。
  Agent 用キャプチャ後の全画面レビュー・気になる点リスト作成で適用する。
---

# Agent 向けビジュアルレビュー（PNG）

## 前提（正とするファイル）

| 用途 | パス |
|------|------|
| 画面と PNG ファイル名の対応表 | `frontend/e2e/agent-review/route-to-png.md` |
| 機械可読なルート一覧 | `frontend/e2e/route-manifest.json` |
| スクリーンショット | `frontend/e2e/agent-review/out/*.{ja,en,in}.png` |
| Capture Run ボンドル | `frontend/tmp/agent-review/agent-review-bundle.json` |

キャプチャ手順は `frontend/e2e/agent-review/README.txt`。**先に** `cd frontend && npm run e2e:capture-for-agent` が成功していること（**ルート数 × 3 言語**の PNG・verify 通過。`ja` / `en` / `in` サフィックス）。**ユーザーに URL やページ指定を求めない。**

メタ情報には **`npm run e2e:capture-for-agent`**（Rails + `dev-session`、`/me` 非モック）であることと、そのときの前提（development・DB・API の一言）を明記する。**API が遅い／無い**と読み込み止まりやすい。キャプチャ spec は **`waitForCaptureStable`** でホスト内 `.master-loading` の消滅まで待つ（詳細・編集向けにスピナー出現の短いポーリングを含む）。**それでも残る**枚はアプリ・ネットワーク・本当の 404 等の別因。

## レビュー範囲（PNG で見ること）

- レイアウトの破綻、はみ出し、明らかな重なり
- 余白・見出し階層・フッターの一貫性（画面間の大きな乖離）
- ローディング／エラー／空状態が**意図せず**主画面を占めていないか（データ欠如や API 不全はあり得る → **枠・タイポ・ボタン**と読み込み異常滞留に注目。**読み込み中...** が主役の枚は **`route-manifest-visual.spec.ts` の待機と両立するか**を踏まえ **`注意`／`要確認`** とする）
- **含めない**: コンポーネント CSS のトークン直書きの列挙（別スキル・別コマンド）

## 言語・i18n（必須・AI 指摘）

各 `pattern` について **`route-to-png.md` の ja / en / in の 3 枚**をセットで見る。機械検出の正は `npm run check-hardcoded-i18n` だが、PNG レビューでも次を**指摘列に必ず反映**する（問題なしは `note: "なし"` と明示）。

| 観点 | `.ja.png` | `.en.png` | `.in.png`（ヒンディー） |
|------|-----------|-----------|-------------------------|
| 表示言語 | 日本語 UI が主（固有名・英数字は可） | **英語** UI が主。見出し・ボタン・説明に**日本語が残っていないか** | **ヒンディー（デーヴァナーガリー）** UI が主。日本語・未翻訳英語の残り |
| 未翻訳キー | `foo.bar.baz` のような **ドット区切りキー**がそのまま出ていないか | 同左 | 同左 |
| 補間 | `%{count}` 等の **プレースホルダが字面のまま**残っていないか | 同左 | 同左 |
| 3 言語の整合 | 同一画面で **ja だけ別言語・in/en だけキー表示**など、言語間で意味が明らかにずれていないか | | |

- **layout / i18n** 列: それぞれ `OK` / `注意` / `要確認`（上記「言語・i18n」節に従う）。
- **`layout: OK` でも `details` に必須**（Paved Road UI 5 項目チェック。問題なしは `note: "なし"` と明示）:

| # | 観点 | 確認内容 |
|---|------|----------|
| 1 | Shell | `funnel-hub` / `section-hub` でヘッダー（title + description）が縦積みか、`page-intro` が `compact-header-card` 内にないか |
| 2 | Pattern | 農場選択が `<select>` + ボタンではなくカード Pattern か |
| 3 | Empty | 空状態が「空カード N 枚」ではなく 1 ブロック + 次アクションか |
| 4 | Buttons | `btn-primary` / `btn-secondary` が `.btn` ベースか、ネイティブ `<button>` 直スタイルがないか |
| 5 | Links | `link-inline` / `btn-link` が定義済みクラスか、未定義クラスを使っていないか |

- **バッチ**: 1 バッチあたり 10〜15 **行（pattern）** × 3 言語。全件時は `routeToPngRange: { start: 1, end: N }` と 3 言語セットであることを明記。

## バッチ運用

- 1 ターンで全枚を極細部まで読むことを前提にしない。
- `route-to-png.md` の表を **10〜15 行ずつ**。各バッチで **対象行番号範囲** と **対応 `out/*.png` 名**を明示してからレビューする。
- **ユーザーが全件の再生成・一括レビューを明示した場合**は、上記に縛られず **1 ターンで全 pattern まとめて**よい。
- 全バッチ終了後、**1 つの JSON ファイル**にマージする（追記または再生成でよい）。

## 必須アウトプット（成果物ベースの「完了」定義）

次を **`frontend/tmp/agent-review/visual-review.json`** に書く（パス固定。ユーザーが別名を指示したときだけ従う）。**リポジトリ内の md は作らない。**

```json
{
  "reviewVersion": 1,
  "captureRunId": "<agent-review-bundle.json の runId>",
  "reviewedAt": "2026-08-08T12:00:00.000Z",
  "routeToPngRange": { "start": 1, "end": 52 },
  "captureCommand": "npm run e2e:capture-for-agent",
  "captureNotes": "development + dev-session、/me 非モック",
  "summary": [
    {
      "num": 1,
      "pattern": "(home)",
      "ja": "home.ja.png",
      "en": "home.en.png",
      "in": "home.in.png",
      "layout": "OK",
      "i18n": "OK",
      "note": "なし"
    }
  ],
  "details": [
    {
      "priority": "P1",
      "rows": [8, 14],
      "patternLabel": "privacy / terms",
      "text": "contact_link 未展開"
    }
  ]
}
```

必須フィールド:

1. **captureRunId**: bundle.runId と一致。**未設定のレビューは Issue 起票不可**。
2. **summary**: 各行（**pattern 単位**）について必ず 1 要素。**行を省略してはならない**。
3. **details**（任意）: `注意` / `要確認` がある行の補足。`collect-ux-findings` が参照。
4. **禁止**: summary なしで総評だけ書く。`e2e/agent-review/` 配下に成果物を置く。

**レビュー完了の目安**: summary が揃い、**captureRunId** が bundle と一致していること。参照した `out/*.png` は **`e2e:capture-for-agent` で verify 済み**の集合と一致させる。

## 実施しないこと

- CSS 当て漏れを PNG だけで列挙する。
- **`e2e:capture-for-agent`** を実行しておらず、`verify-capture-complete` / **bundle 生成**を通していない `out/` で「全件レビュー済み」とする。
- **captureRunId なし**で visual-review を確定し Issue 起票に使う。
- ユーザーに「どのページを見るか」を聞いてレビュー範囲を先送りする。
- レビュー成果物を git にコミットする。

## 関連

- キャプチャ・マニフェスト: **`frontend-css-route-audit`**（CSS とキャプチャ）、本スキルは **レビュー成果物の型**に特化。
- 機械監査: `cd frontend && npm run audit:css-tokens`
- **Issue 起票パイプライン**: 本ファイル生成後 → **`ux-issue-pipeline`**（フェーズ 2b 認知導線 → 4–5: `collect-ux-findings.mjs` → **`ux-issue-creator`**）
- **認知・導線レビュー**: **`ux-cognitive-guidance-review`**（わからないときの救済。レイアウト/i18n の重複指摘は避ける）
