# 「計画作成に失敗しました」中寄せが効かない理由と対応

## これまでやったこと

1. **エラーを固定フッター内に表示**  
   `public-plan-select-crop.component.ts`: エラー時は `.fixed-bottom-bar-error` を固定フッター内に表示するようにした。

2. **CSS で「中央」を指定**  
   `public-plan.component.css` で:
   - `.fixed-bottom-bar-error` に `text-align: center` を付与
   - `.fixed-bottom-bar-container:has(.fixed-bottom-bar-error)` で `display: flex; justify-content: center; align-items: center` を指定

3. **エラー時はコンテナをフル幅に**  
   `:has(.fixed-bottom-bar-error)` のときだけコンテナを `width: 100%; max-width: 100%` にし、flex で中央寄せするようにした。

## 治らない理由

1. **`:has()` が効いていない**  
   `.fixed-bottom-bar-container:has(.fixed-bottom-bar-error)` は、子に `.fixed-bottom-bar-error` があるときだけ適用される。  
   - ブラウザが `:has()` をサポートしていない、または  
   - Angular の View Encapsulation でセレクタが変わって `:has()` がマッチしない  
   場合、このルールが当たらず、コンテナは **flex にならない**。

2. **コンテナのデフォルトが app.css 側**  
   `app.css` の `.fixed-bottom-bar-container` には  
   `max-width: 900px; margin: 0 auto; padding: ...; width: 100%` のみで、  
   `display: flex` や `justify-content: center` はない。  
   そのため、`:has()` のルールが当たらないときは:
   - コンテナは単なるブロック
   - 中の `.fixed-bottom-bar-error` は `width: auto` で内容幅
   - ブロックは左寄せになるので、**見た目は左寄せ**のままになる。

3. **`text-align: center` だけでは足りない**  
   中央にしたいのは「エラーメッセージのブロック全体」であり、  
   ブロック自体が左寄せだと、`text-align: center` は「そのブロックの内側」でしか効かない。  
   そのため、**コンテナで flex 中央寄せ**が必要。

## 対応方針

**`:has()` に依存しないようにする。**

- テンプレートで「エラー時」にコンテナ（またはフッター）に専用クラスを付与する（例: `fixed-bottom-bar-container--error`）。
- CSS ではそのクラスに対してだけ  
  `display: flex; justify-content: center; align-items: center;` と幅を指定する。  
これでエラー時は必ずコンテナが flex になり、メッセージが固定フッターの中央に表示される。
