# タスクスケジュール ドロップ後の読み込み表示要因分析

## 概要
`plans/28/task_schedule` ページでタスクをドラッグ&ドロップした際に、読み込み中であることが視覚的に表示されてしまう問題の要因を分析します。

## 読み込みが行われる要因の特定

### 1. ドロップ処理の流れ（dropTask メソッド）

タスクをドロップすると、以下の処理が実行されます：

1. **ドロップ検証**: `canDropOnCell` でドロップ可能かチェック
2. **セルにpending状態を付与**: `markCellPending(cell, true)` で `timeline-day-cell--pending` クラスを追加
3. **APIリクエスト**: `patchItem` でサーバーに更新リクエストを送信
4. **週データの再取得**: `refreshCurrentWeek({ showLoading: false })` で現在の週データを再取得
5. **pending状態の解除**: `markCellPending(cell, false)` でクラスを削除

### 2. 視覚的な読み込み表示の要因

#### 要因1: markCellPending による pending クラスの追加

`markCellPending` メソッド（422-433行目）では、ドロップされたセルに `timeline-day-cell--pending` クラスを追加します。

CSS（252-264行目）では、このクラスに対して以下のスタイルが適用されます：
- `opacity: 0.6` でセルを半透明にする
- `::after` 疑似要素で点線のボーダーを表示
- `timeline-pending-pulse` アニメーションで点滅効果を付与

これにより、ドロップされたセルが視覚的に「読み込み中」であることが明確に示されます。

#### 要因2: refreshCurrentWeek による再レンダリング

`dropTask` メソッド（380行目）では、更新成功後に `refreshCurrentWeek({ showLoading: false })` を呼び出します。

`refreshCurrentWeek` メソッド（1375-1381行目）は、現在の週の開始日を取得して `loadWeek` を呼び出します。

`loadWeek` メソッド（88-118行目）では：
- `options.showLoading !== false` の場合に `showLoading()` を呼び出す（ただし、`dropTask` では `showLoading: false` を渡しているため、この場合は呼ばれない）
- サーバーからJSONデータを取得
- `render()` メソッドを呼び出して画面を再描画

#### 要因3: render メソッドによるHTMLの置き換え

`render` メソッド（120-146行目）では：
- `this.contentTarget.innerHTML = html` でコンテンツ全体を置き換える
- この置き換え処理中、一時的にコンテンツが消える可能性がある
- 新しいHTMLが生成されるまでの間、画面が空白になる可能性がある

#### 要因4: 非同期処理によるタイミングの問題

`dropTask` メソッドは `async` 関数であり、以下の非同期処理が順次実行されます：

1. `patchItem` の完了を待つ（376-379行目）
2. `refreshCurrentWeek` の完了を待つ（380行目）
3. `finally` ブロックで `markCellPending(cell, false)` を実行（385行目）

この非同期処理の順序により、以下のタイミングで読み込み表示が発生します：
- `patchItem` のリクエスト中（ネットワーク遅延がある場合）
- `refreshCurrentWeek` の `loadWeek` によるデータ取得中
- `render` によるHTML再生成中

#### 要因5: CSSアニメーションによる視覚的フィードバック

`timeline-day-cell--pending` クラスには、`timeline-pending-pulse` アニメーション（403-410行目）が適用されます。

このアニメーションは：
- `opacity` を 0.4 から 1 に変化させる
- `1s ease-in-out infinite alternate` で無限に繰り返す
- 点滅効果により、読み込み中であることを強調する

### 3. 読み込み表示が発生する具体的なタイミング

1. **ドロップ直後**: `markCellPending(cell, true)` が呼ばれ、セルに pending クラスが追加される
2. **APIリクエスト中**: `patchItem` のリクエストが完了するまで（通常は数ミリ秒〜数百ミリ秒）
3. **データ再取得中**: `refreshCurrentWeek` → `loadWeek` によるデータ取得中（通常は数ミリ秒〜数百ミリ秒）
4. **再レンダリング中**: `render` メソッドによるHTML生成と置き換え中（通常は数ミリ秒）

合計で、通常は数百ミリ秒〜1秒程度の間、読み込み表示が継続します。

### 4. 問題点のまとめ

現在の実装では、以下の理由により読み込み表示が発生します：

1. **意図的な視覚的フィードバック**: `markCellPending` により、ユーザーに処理中であることを示すための意図的な表示
2. **データ再取得の必要性**: 更新後の最新状態を表示するために、週データを再取得している
3. **HTML全体の再生成**: `render` メソッドがHTML全体を再生成するため、一時的な空白が発生する可能性がある
4. **非同期処理の順次実行**: 複数の非同期処理が順次実行されるため、合計時間が長くなる

### 5. 改善方針

読み込み表示を非表示にするには、以下のアプローチが考えられます：

1. **pending クラスの追加を削除**: `markCellPending(cell, true)` を呼ばない
2. **最適化された更新**: サーバーからのレスポンスを直接使用して、特定のタスクのみを更新する（全体再取得を避ける）
3. **楽観的更新**: ドロップ時に即座にUIを更新し、バックグラウンドでサーバーと同期する
4. **部分的な再レンダリング**: HTML全体を置き換えるのではなく、変更された部分のみを更新する

最もシンプルな解決策は、`markCellPending` の呼び出しを削除することです。ただし、エラー時の処理を考慮する必要があります。

