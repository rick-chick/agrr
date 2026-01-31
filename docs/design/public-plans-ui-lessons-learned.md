# 無料作付画面（Public Plans）UI 修正で得られた知見

本ドキュメントは、無料作付画面のデザイン・表示まわりの修正を通じて得られた知見を整理したものです。

---

## 1. i18n（ngx-translate）の補間構文

### 知見
- **ngx-translate は `{{ paramName }}` で補間する。Rails でよく使う `%{paramName}` はそのまま表示される。**
- i18n JSON が Rails 由来や共通フォーマットで `%{count}` などになっていると、フロントでは置換されず「%{count}種類の作物」のようにそのまま出る。

### 対応
- 無料作付で **Angular から参照するキー** は、プレースホルダーを `{{ paramName }}` に統一した。
  - 例: `public_plans.optimizing.crops_count` → `"{{ count }}種類の作物"`
  - 例: `public_plans.optimizing.progress.elapsed_time` → `"⏳ {{ time }}秒"`

### 運用
- フロント専用のキー、または Angular で `translate` パイプにオブジェクトを渡すキーは、JSON 側で `{{ ... }}` を使う。
- Rails と共有するキーで `%{...}` のままにする場合は、フロントでは別キーを用意するか、補間用のラッパーを検討する。

---

## 2. 白地に溶け込む問題（視認性）

### 知見
- **CSS 変数が app.css の `:root` のみで定義されていると、コンポーネントの読み込み順・スコープで効かないことがあり、背景や文字色が未適用で「白地に白」になる。**
- 進捗バー（1 地域 / 2 サイズ / 3 作物）、「最適化中」バッジ、ヘッダーカードなどで発生した。

### 対応
- **進捗バー**
  - `.compact-header-card`: 背景を `var(--color-surface-hover)`、枠を `1px solid var(--color-border)` にし、ページ背景と区別。
  - `.compact-step`: `background: rgba(255,255,255,0.7)` と `border` を付与。
  - `.step-number` / `.step-label`: `var(--color-*, フォールバック値)` で未定義時も視認できるようにした。
- **「最適化中」バッジ**
  - 変数に依存しない **ハードコード色**（`#90cdf4` 背景、`#2b6cb0` 文字）にし、常に視認可能にした。
- **ヘッダーカード**
  - app.css の `.compact-header-card` を削除し、`public-plan.component.css` のみで定義（背景・枠を明示）。

### 運用
- 重要なラベル・バッジ・カードは、**フォールバック付きの `var()`** または **ハードコード色** を検討する。
- グローバルとコンポーネントで同じクラスを定義している場合は、どちらか一方に寄せる。

---

## 3. 進捗バー（地域・サイズ・作物）のデザイン統一

### 知見
- **app.css と public-plan.component.css の両方に `.compact-header-card` があると、読み込み順や詳細度で画面ごとに見た目が変わる。**
- 「地域・サイズ・作物の3画面で同じデザインに」という要望に対して、定義が二重だったことが原因だった。

### 対応
- app.css の `.compact-header-card` を削除。
- 進捗バーまわりのスタイルは **public-plan.component.css のみ** に集約（地域・サイズ・作物の3画面は同じ `styleUrl` を参照）。

### 運用
- 複数画面で共有するデザインは、**定義を1箇所にまとめる**。グローバルとコンポーネントで同じクラス名を使い分けない。

---

## 4. 「中寄せ」の解釈と実装

### 知見
- **「中寄せ」「まんなか」は文脈で意味が変わる。**
  - 固定フッター**内**の中央
  - **画面全体（コンテンツ領域）**の中央
- **`:has()` に依存した中央寄せは、ブラウザサポートや Angular の View Encapsulation で効かないことがある。**

### 経緯
- 作物選択で計画作成失敗時、「計画作成に失敗しました」を固定フッター内で中央に表示したいという要望。
- `text-align: center` だけではブロック自体が左寄せのまま。
- `.fixed-bottom-bar-container:has(.fixed-bottom-bar-error)` で flex 中央寄せにしたが、`:has()` が当たらず改善しないケースがあった。
- クラス付与（`[class.fixed-bottom-bar-container--error]="!!control.error"`）に変えても、期待どおりにならないことがあった。
- 「もしかしたらこっちか？」を受けて、**固定フッター内ではなく、コンテンツ領域の中央**に表示する解釈に変更（`.create-plan-error-center`）。エラー時は固定フッターを非表示にした。

### 運用
- 中央寄せは **状態用クラスを付与してスタイルを当てる**（`:has()` に頼らない）。
- 「どこを中央にするか」が曖昧な場合は、**画面中央（コンテンツ領域）** と **特定ブロック内の中央** を分けて確認する。

---

## 5. エラー表示の重複

### 知見
- **同じエラーメッセージを複数箇所に出すと冗長で、ユーザーから「いらない」と指摘されうる。**

### 対応
- 最適化失敗時:「計画作成に失敗しました」が progress-header と error-message-container（⚠️＋タイトル）の2回表示になっていた。
- 下段の **⚠️ ＋ 同じタイトル** を削除し、progress-header の1回表示＋その下のアクションリンクのみにした。

### 運用
- エラーは **1メッセージ1箇所** を基本にし、必要なら「短いメッセージ＋詳細」のように役割を分ける。

---

## 6. 左寄せの維持

### 知見
- **「中央にしろ」と「左寄せのままでいい」は、画面やブロックごとに要望が分かれる。**

### 対応
- 最適化失敗時: 固定プログレスバー内を一時的に中央寄せにしていたが、「計画作成に失敗しましたは左寄せのままでいい」という要望で、失敗時用の中央寄せクラス・CSS を削除し、左寄せに戻した。

### 運用
- 中央寄せは「全部」ではなく、**どのブロック・どの画面を中央にするか** を都度確認する。

---

## 関連ドキュメント

- [public-plans-rails-angular-design-diff.md](./public-plans-rails-angular-design-diff.md) - Rails と Angular の無料作付画面のデザイン差分
- [public-plans-error-center-explanation.md](./public-plans-error-center-explanation.md) - エラー中寄せが効かなかった理由と対応
- [public-plans-progress-bar-white-on-white-investigation.md](./public-plans-progress-bar-white-on-white-investigation.md) - 進捗バー白地問題の調査
- [public-plans-optimizing-badge-white-investigation.md](./public-plans-optimizing-badge-white-investigation.md) - 「最適化中」バッジ白地問題の調査
