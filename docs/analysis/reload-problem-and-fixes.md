# リロード問題の整理と対応

## 概要

フロントで「画面が延々とリロードする」「リロードして見える」と報告された事象の原因と対応をまとめる。

## 1. 原因と対応一覧

| 現象 | 原因 | 対応 | 対象 |
|------|------|------|------|
| edit 画面が延々とリロードして見える | 子コンポーネントに「毎回新しいオブジェクト」を渡していた | テンプレートにバインドする値を getter ではなくプロパティにし、入力変更時（ngOnChanges）だけ更新する | FarmMapComponent（farm edit/create/detail） |
| UNDO 後に一覧へ飛んでしまう | 詳細画面の Undo 成功時コールバックで `router.navigate` していた | `onRestored` で一覧へ遷移せず、`view.reload()` で詳細を再取得する | 全マスタ詳細（crop, farm, pest, pesticide, agricultural-task, interaction-rule） |

## 2. FarmMapComponent の修正（edit まわりのリロード）

**原因**: `options` を getter で `return { layers: [...], zoom: 13, center: [...] }` のように返していた。  
Change Detection のたびに getter が実行され、毎回新しいオブジェクトが Leaflet に渡る → マップが再初期化され、edit 画面が「延々とリロード」しているように見えた。

**対応**:
- `options` を getter ではなくプロパティにした。
- 初期値はコンストラクタ時一度だけ代入。
- `latitude` / `longitude` が変わったときだけ `ngOnChanges` 内で `this.options = { ...this.options, center }` のように更新。

**影響範囲**: FarmMapComponent を使っている画面のみ。
- farm-edit
- farm-create  
- farm-detail  

crop / pest / pesticide / agricultural-task / interaction-rule / fertilize の edit は FarmMap を使っていないため、この種の「options getter によるリロード」は発生しない。

## 3. UNDO 時のリロード（詳細画面）

**原因**: 詳細画面で削除 → Undo すると、`onRestored` に `() => this.router.navigate(['/crops'])` などを渡しており、Undo 成功時に一覧へ遷移していた。画面が切り替わる＝「リロード」と感じられる。

**対応**:
- 各詳細 View に `reload(): void` を追加。
- 各詳細 Component で `reload()` を実装（ルートの id を取得して `load(id)` を呼ぶ）。
- 各詳細 Presenter の `showWithUndo` の第4引数を `() => this.router.navigate([...])` から `() => this.view?.reload()` に変更。

**影響範囲**: 全マスタ詳細（crop, farm, pest, pesticide, agricultural-task, interaction-rule）。一覧画面は従来どおり `dto.refresh`（= `() => this.load()`）のまま。

## 4. 再発防止（ルール）

- **テンプレートにバインドする値で「毎回新しいオブジェクト／配列」を返す getter は使わない。**  
  子コンポーネントやディレクティブが参照比較で再初期化する場合、CD のたびに再実行され、リロードまわりやパフォーマンス問題の原因になる。
- オプションやレイヤーなどは **プロパティで持ち、`ngOnChanges` や入力の変更時だけ更新する** 形にする。
- 詳細画面で Undo 後の振る舞いを変える場合は、**遷移ではなく「同じ画面で再取得」** を優先する（`view.reload()` など）。

## 5. 他にリロードして見える場合

crop / pest など FarmMap を使わない edit で同様の「リロード」が出る場合は、別要因の可能性がある。例:

- ルートの再評価やガードでコンポーネントが再生成されている
- 親の `*ngIf` で子が破棄・再生成されている
- どこかで `load()` や `ngOnInit` が繰り返し呼ばれている（例: route.params の subscribe で毎回 load している）

その場合は「どの画面・どの操作のとき・ローディングが続くか／フォームが消えるか」などを切り分けて調査する。
