# デザインサンプル集（カード基調・トークン統一）

SKILL.md の「5. 具体例」を補うサンプル。カードを基調としたレイアウト・フォーム・一覧の実装例。トークンは [DESIGN_TOKENS.md](DESIGN_TOKENS.md) に従う。

---

## 1. ページレイアウト（カード積み）

ページ全体を「カードの積み重ね」として構成する例。

### HTML（main + カードセクション）

```html
<main class="page-main">
  <header class="page-header">
    <h1 class="page-title">マスタ一覧</h1>
    <p class="page-description">農場・作物・肥料などを管理します。</p>
  </header>

  <section class="section-card" aria-labelledby="section-list-heading">
    <h2 id="section-list-heading" class="section-title">農場</h2>
    <!-- 一覧コンテンツ -->
  </section>

  <section class="section-card" aria-labelledby="section-actions-heading">
    <h2 id="section-actions-heading" class="section-title">操作</h2>
    <!-- アクションコンテンツ -->
  </section>
</main>
```

### CSS（トークンで余白・角丸・背景）

```css
.page-main {
  padding: var(--space-4) var(--space-6);
  background: var(--color-background);
  min-height: 100vh;
}

.page-header {
  margin-bottom: var(--space-6);
}

.page-title {
  font-size: var(--font-size-xl);
  font-weight: var(--font-weight-bold);
  color: var(--color-text);
  margin: 0 0 var(--space-2) 0;
}

.page-description {
  font-size: var(--font-size-sm);
  color: var(--color-text-secondary);
  margin: 0;
}

.section-card {
  width: 100%;
  background: var(--color-surface);
  border-radius: var(--radius-lg);
  padding: var(--space-4);
  margin-bottom: var(--space-4);
  border: 1px solid var(--color-border);
  box-shadow: var(--shadow-card);
}

/* 一覧・編集・詳細いずれも幅制限なし。section-card は width: 100% のみ */

.section-title {
  font-size: var(--font-size-lg);
  font-weight: var(--font-weight-medium);
  color: var(--color-text);
  margin: 0 0 var(--space-3) 0;
  padding-bottom: var(--space-2);
  border-bottom: 1px solid var(--color-divider);
}
```

---

## 2. 一覧（カードリスト）

リスト項目をカードで表現する。**カード内にボタン（編集・削除など）を配置する**パターンを推奨する。一覧の並びは**レスポンシブに 1 列〜3 列**（狭い幅で 1 列、タブレットで 2 列、デスクトップで 3 列）とする。

### 2a. カード内にボタンを配置（推奨）

カードはコンテナとし、本文エリア（タイトル・メタ）とアクションエリア（ボタン）に分ける。カード全体を `<a>` にしないことで、ボタンとリンクの入れ子を避ける。`.card-list` は **CSS Grid** とし、ブレークポイント（DESIGN_TOKENS 7. レスポンシブ）で列数を切り替える。

#### HTML（ul + カード + 本文リンク + アクション）

```html
<ul class="card-list" role="list">
  <li *ngFor="let item of items" class="card-list__item">
    <article class="item-card">
      <a [routerLink]="item.link" class="item-card__body">
        <span class="item-card__title">{{ item.name }}</span>
        <span class="item-card__meta" *ngIf="item.meta">{{ item.meta }}</span>
      </a>
      <div class="item-card__actions">
        <a mat-button [routerLink]="item.link">詳細</a>
        <button mat-button type="button" (click)="onEdit(item)">編集</button>
        <button mat-stroked-button type="button" (click)="onDelete(item)" aria-label="削除">削除</button>
      </div>
    </article>
  </li>
</ul>
```

#### CSS（レスポンシブ 1〜3 列）

`.card-list` を CSS Grid にし、画面幅に応じて 1 列（デフォルト）→ 2 列（768px 以上）→ 3 列（1024px 以上）。ブレークポイントの値は DESIGN_TOKENS の `--breakpoint-md`（768px）、`--breakpoint-lg`（1024px）に合わせる。

```css
.card-list {
  display: grid;
  grid-template-columns: 1fr;
  gap: var(--space-3);
  list-style: none;
  margin: 0;
  padding: 0;
}

@media (min-width: 768px) {
  .card-list {
    grid-template-columns: repeat(2, 1fr);
  }
}

@media (min-width: 1024px) {
  .card-list {
    grid-template-columns: repeat(3, 1fr);
  }
}

.card-list__item {
  margin: 0;
}

.item-card {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: var(--space-3);
  padding: var(--space-4);
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-lg);
  transition: border-color 0.15s ease;
}

.item-card:hover {
  border-color: var(--color-border);
}

.item-card__body {
  flex: 1 1 auto;
  min-width: 0;
  text-decoration: none;
  color: var(--color-text);
}

.item-card__body:hover {
  color: var(--color-primary);
}

.item-card__body:focus-visible {
  outline: 2px solid var(--color-primary);
  outline-offset: 2px;
  border-radius: var(--radius-md);
}

.item-card__title {
  font-size: var(--font-size-md);
  font-weight: var(--font-weight-medium);
  display: block;
  margin-bottom: var(--space-1);
}

.item-card__meta {
  font-size: var(--font-size-sm);
  color: var(--color-text-secondary);
}

.item-card__actions {
  display: flex;
  flex-shrink: 0;
  gap: var(--space-3);
}
```

#### 2a 補足: Material なし（CDK のみ・ネイティブボタン）

`mat-button` を使わない場合は、トークン準拠の `.btn-primary` / `.btn-secondary` / `.btn-danger` を使う。HTML は 2a と同じ構造（`<article class="item-card">` + `item-card__body` + `item-card__actions`）とし、ボタンは `btn-secondary`（編集・詳細）、`btn-danger`（削除）を付与する。Create 等の主アクションは `section-card__header-actions` 内に `btn-primary` で配置する。実装例は `_master-layout.css` の「パターンB: カード内に本文＋アクション」を参照。

一覧の編集・削除ボタンは**同じ水平 padding**（例: `.btn-secondary` と `.btn-danger` ともに `var(--space-4)`）を使い、並んだときに幅が揃うようにする。文言差で幅を完全に揃えたい場合は、`.item-card__actions` 内で両方に同じ **min-width** を指定してもよい。

#### Angular Material を使う場合（mat-card + ボタン）

```html
<ul class="card-list" role="list">
  <li *ngFor="let item of items" class="card-list__item">
    <mat-card class="item-card-mat">
      <mat-card-content class="item-card-mat__body">
        <a [routerLink]="item.link" class="item-card-mat__link">
          <span class="item-card-mat__title">{{ item.name }}</span>
          <span class="item-card-mat__meta" *ngIf="item.meta">{{ item.meta }}</span>
        </a>
      </mat-card-content>
      <mat-card-actions class="item-card-mat__actions">
        <a mat-button [routerLink]="item.link">詳細</a>
        <button mat-button type="button" (click)="onEdit(item)">編集</button>
        <button mat-stroked-button type="button" (click)="onDelete(item)" aria-label="削除">削除</button>
      </mat-card-actions>
    </mat-card>
  </li>
</ul>
```

```css
.item-card-mat {
  padding: var(--space-4);
  border-radius: var(--radius-lg);
}

.item-card-mat__body {
  margin-bottom: var(--space-3);
}

.item-card-mat__link {
  text-decoration: none;
  color: var(--color-text);
}

.item-card-mat__link:hover {
  color: var(--color-primary);
}

.item-card-mat__title {
  font-size: var(--font-size-md);
  font-weight: var(--font-weight-medium);
  display: block;
  margin-bottom: var(--space-1);
}

.item-card-mat__meta {
  font-size: var(--font-size-sm);
  color: var(--color-text-secondary);
}

.item-card-mat__actions {
  padding: 0;
  margin: 0;
  display: flex;
  gap: var(--space-3);
}
```

### 2b. カード全体をリンクにする場合（シンプル一覧）

アクションが不要な一覧では、カード全体をリンクにしてよい。

```html
<ul class="card-list" role="list">
  <li *ngFor="let item of items" class="card-list__item">
    <a [routerLink]="item.link" class="item-card item-card--link-only">
      <span class="item-card__title">{{ item.name }}</span>
      <span class="item-card__meta" *ngIf="item.meta">{{ item.meta }}</span>
    </a>
  </li>
</ul>
```

```css
.item-card--link-only {
  display: block;
  padding: var(--space-4);
  text-decoration: none;
  color: var(--color-text);
}

.item-card--link-only:hover {
  background: var(--color-surface-hover, #f8fafc);
  border-color: var(--color-primary);
}
```

### 2c. 一覧画面のタイトルとチェックリスト（ださい防止）

一覧で「タイトル重複」「ボタン詰まり」「平坦な見た目」を防ぐためのルール。SKILL 4.7 に対応。

#### タイトル冗長の避け方

- **1 セクションだけのマスタ一覧**（作物・肥料・害虫など）では、`h1.page-title` に「〇〇一覧」を置き、**セクション見出し `h2.section-title` はページタイトルと同一にしない**。
  - **推奨 A**: セクション見出しを省略し、`<section class="section-card" aria-labelledby="page-title">` のように `h1` の id を `page-title` にして `aria-labelledby` で参照する。
  - **推奨 B**: セクション見出しを使う場合は別文言にする（例: 「一覧」「登録済みの作物」）。i18n の `list_heading` を「一覧」や「登録済み」に変更する。

```html
<!-- 推奨 A: セクション見出しなし -->
<main class="page-main">
  <header class="page-header">
    <h1 id="page-title" class="page-title">作物一覧</h1>
    <p class="page-description">作物マスタの一覧です。</p>
  </header>
  <section class="section-card" aria-labelledby="page-title">
    <div class="section-card__header-actions">...</div>
    <ul class="card-list">...</ul>
  </section>
</main>
```

#### アクション間の余白（タップしやすさ）

- `.item-card__actions` の `gap` は **`var(--space-3)`**（12px）以上を推奨。`--space-2`（8px）だとボタンが詰まって見え、モバイルでタップしづらい。

```css
.item-card__actions {
  display: flex;
  flex-shrink: 0;
  gap: var(--space-3);  /* 推奨: --space-2 より --space-3 */
  align-items: center;
}
```

#### 一覧アイテムのホバー

- `article.item-card` にホバー時の影または枠線・背景の変化を付ける。`_master-layout.css` では `--shadow-card-hover` を利用する。

```css
article.item-card:hover {
  border-color: var(--color-border);
  box-shadow: var(--shadow-card-hover);
}
```

#### 一覧画面チェックリスト（PR 前）

- [ ] ページタイトル（h1）とセクション見出し（h2）が同一文言でない
- [ ] 一覧カードはレスポンシブで 1〜3 列（`.card-list` を CSS Grid、768px/1024px で列数切り替え）
- [ ] `.item-card__actions` の gap が `var(--space-3)` 以上
- [ ] 一覧アイテムにホバー時の変化（影 or 枠線 or 背景）がある
- [ ] 主アクション（追加）は `btn-primary`、詳細・編集は `btn-secondary`、削除は `btn-danger`
- [ ] 編集・削除ボタンの高さ・幅が統一されている（同じ padding または min-width）
- [ ] セカンダリボタンのホバーで `--color-surface-hover` が効いている

---

## 3. 詳細画面（単一カード）

1 件の詳細を 1 枚のカードで表示する例。

**レイアウト・カード幅・レスポンシブ・スマホ**は編集画面と同様に [7. 登録・編集画面テンプレート](#7-登録編集画面テンプレート一般構造カードレスポンシブスマホ) の 7a（一般構造）・7c（カード幅・中央配置・レスポンシブ）・7d（タップ領域・アクション sticky）に従う。実装は共通 `_master-layout.css` および 7c を参照する。

**ボタン階層**: 編集は主アクションのため `btn-primary`、戻るは `btn-secondary`、削除は破壊的アクションのため `btn-danger` を使う。Edit を目立たせることで操作の優先度を明確にする。

### HTML

```html
<main class="page-main">
  <section class="detail-card" aria-labelledby="detail-heading">
    <h1 id="detail-heading" class="detail-card__title">{{ entity.name }}</h1>
    <dl class="detail-card__list">
      <div class="detail-row">
        <dt class="detail-row__term">ID</dt>
        <dd class="detail-row__value">{{ entity.id }}</dd>
      </div>
      <div class="detail-row">
        <dt class="detail-row__term">説明</dt>
        <dd class="detail-row__value">{{ entity.description }}</dd>
      </div>
    </dl>
    <div class="detail-card__actions">
      <a [routerLink]="['/items', entity.id, 'edit']" class="btn-primary">編集</a>
      <a routerLink="/items" class="btn-secondary">戻る</a>
      <button type="button" class="btn-danger" (click)="onDelete()" aria-label="削除">削除</button>
    </div>
  </section>
</main>
```

### 複数カードがある場合（地図・圃場一覧など）

詳細画面で `detail-card` のほかに地図・一覧などの `section-card` がある場合も、**幅制限なし**（SKILL 5a）。カードは利用可能な幅をそのまま使う。

```html
<main class="page-main">
  <section class="detail-card">...</section>
  <section class="section-card" aria-labelledby="map-heading">
    <h2 id="map-heading" class="section-title">地図</h2>
  </section>
  <section class="section-card" aria-labelledby="fields-heading">
    <h2 id="fields-heading" class="section-title">圃場</h2>
  </section>
</main>
```

### CSS

カードの幅・レスポンシブ（768px/480px）・アクションの sticky は 7c・7d および `_master-layout.css` に合わせる。以下は基本スタイル。`detail-card` は幅制限なし（`width: 100%` のみ）。

```css
.detail-card {
  width: 100%;
  background: var(--color-surface);
  border-radius: var(--radius-lg);
  padding: var(--space-4);
  border: 1px solid var(--color-border);
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.06);
}

.detail-card__title {
  font-size: var(--font-size-xl);
  font-weight: var(--font-weight-bold);
  color: var(--color-text);
  margin: 0 0 var(--space-4) 0;
  padding-bottom: var(--space-3);
  border-bottom: 1px solid var(--color-divider);
}

.detail-card__list {
  margin: 0 0 var(--space-4) 0;
  padding: 0;
}

.detail-row {
  display: flex;
  gap: var(--space-3);
  padding: var(--space-2) 0;
  border-bottom: 1px solid var(--color-divider);
}

.detail-row:last-child {
  border-bottom: none;
}

.detail-row__term {
  font-size: var(--font-size-sm);
  color: var(--color-text-secondary);
  font-weight: var(--font-weight-medium);
  flex: 0 0 120px;
  margin: 0;
}

.detail-row__value {
  font-size: var(--font-size-md);
  color: var(--color-text);
  margin: 0;
}

.detail-card__actions {
  display: flex;
  gap: var(--space-2);
  padding-top: var(--space-3);
  border-top: 1px solid var(--color-divider);
}
```

---

## 4. フォーム（カード内）

登録・編集の全体構造・レスポンシブ・スマホは「7. 登録・編集画面テンプレート」を参照。

作成・編集フォームをカードで囲む例。

### HTML

```html
<section class="form-card" aria-labelledby="form-heading">
  <h2 id="form-heading" class="form-card__title">新規登録</h2>
  <form [formGroup]="form" (ngSubmit)="onSubmit()" class="form-card__form">
    <mat-form-field appearance="outline" class="form-field">
      <mat-label>名前</mat-label>
      <input matInput formControlName="name" type="text" />
      <mat-error *ngIf="form.get('name')?.hasError('required')">必須です</mat-error>
    </mat-form-field>
    <mat-form-field appearance="outline" class="form-field">
      <mat-label>説明</mat-label>
      <textarea matInput formControlName="description" rows="3"></textarea>
    </mat-form-field>
    <div class="form-card__actions">
      <button mat-flat-button color="primary" type="submit">保存</button>
      <button mat-button type="button" (click)="onCancel()">キャンセル</button>
    </div>
  </form>
</section>
```

### CSS

```css
.form-card {
  background: var(--color-surface);
  border-radius: var(--radius-lg);
  padding: var(--space-4);
  border: 1px solid var(--color-border);
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.06);
  max-width: 480px;
}

.form-card__title {
  font-size: var(--font-size-lg);
  font-weight: var(--font-weight-medium);
  color: var(--color-text);
  margin: 0 0 var(--space-4) 0;
  padding-bottom: var(--space-2);
  border-bottom: 1px solid var(--color-divider);
}

.form-card__form {
  display: flex;
  flex-direction: column;
  gap: var(--space-4);
}

.form-field {
  width: 100%;
}

.form-card__actions {
  display: flex;
  gap: var(--space-2);
  padding-top: var(--space-2);
}
```

### 4b. フォーム（Material なし・ネイティブ HTML）

`@angular/material` を導入していない場合、ネイティブの `<input>`, `<select>`, `<textarea>` に CSS で mat-form-field 相当の見た目を付ける。 outline 風（枠線で囲む）の入力欄、フォーカス・ホバー時の状態遷移をトークンで定義する。

#### HTML（label + input/select/textarea）

ラベルは `for`/`id` で input と紐付ける。ラベル文言は `form-card__field-label` で囲む。

```html
<section class="form-card" aria-labelledby="form-heading">
  <h2 id="form-heading" class="form-card__title">新規登録</h2>
  <form (ngSubmit)="onSubmit()" #f="ngForm" class="form-card__form">
    <label class="form-card__field" for="name">
      <span class="form-card__field-label">名前</span>
      <input id="name" name="name" type="text" [(ngModel)]="control.formData.name" required />
    </label>
    <label class="form-card__field" for="description">
      <span class="form-card__field-label">説明</span>
      <textarea id="description" name="description" [(ngModel)]="control.formData.description" rows="3"></textarea>
    </label>
    <label class="form-card__field" for="crop">
      <span class="form-card__field-label">作物</span>
      <select id="crop" name="crop_id" [(ngModel)]="control.formData.crop_id" required>
        <option [value]="0">-- 選択 --</option>
        <option *ngFor="let c of crops" [value]="c.id">{{ c.name }}</option>
      </select>
    </label>
    <div class="form-card__actions">
      <button type="submit" class="btn-primary" [disabled]="f.invalid || control.saving">保存</button>
      <a routerLink="/list" class="btn-secondary">戻る</a>
    </div>
  </form>
</section>
```

#### CSS（トークンでフォーカス・ホバー・select 矢印を定義）

```css
.form-card__field {
  display: flex;
  flex-direction: column;
  gap: var(--space-1);
  width: 100%;
}

.form-card__field-label {
  font-size: var(--font-size-sm);
  color: var(--color-text);
  font-weight: var(--font-weight-medium);
}

.form-card__field input,
.form-card__field textarea,
.form-card__field select {
  display: block;
  width: 100%;
  padding: var(--space-2) var(--space-3);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  font-size: var(--font-size-md);
  background: var(--color-surface);
  transition: border-color 0.15s ease, box-shadow 0.15s ease;
}

.form-card__field input:hover,
.form-card__field textarea:hover,
.form-card__field select:hover {
  border-color: var(--color-input-hover, var(--color-text-secondary));
}

.form-card__field input:focus,
.form-card__field textarea:focus,
.form-card__field select:focus {
  outline: none;
  border-color: var(--color-input-focus, var(--color-primary));
  box-shadow: var(--shadow-input-focus, 0 0 0 2px rgba(37, 99, 235, 0.2));
}

.form-card__field textarea {
  min-height: var(--form-textarea-min-height, 80px);
  resize: vertical;
}

/* select: ブラウザデフォルト矢印を消し、カスタム矢印を表示 */
.form-card__field select {
  appearance: none;
  background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='12' viewBox='0 0 12 12'%3E%3Cpath fill='%2364748b' d='M6 8L1 3h10z'/%3E%3C/svg%3E");
  background-repeat: no-repeat;
  background-position: right var(--space-3) center;
  padding-right: var(--space-8);
}
```

トークンは [DESIGN_TOKENS.md の「3. 色トークン」フォーム入力](DESIGN_TOKENS.md) を参照。`styles.css` の `:root` に以下を追加する：

```css
--color-input-focus: var(--color-primary);
--color-input-hover: #94a3b8;  /* --color-border より濃い */
--color-input-arrow: var(--color-text-secondary);
--shadow-input-focus: 0 0 0 2px rgba(37, 99, 235, 0.2);
```

---

## 5. トークン前提（:root 抜粋）

上記サンプルで使うトークン。全体は [DESIGN_TOKENS.md](DESIGN_TOKENS.md) を参照。

```css
:root {
  --color-primary: #2563eb;
  --color-primary-hover: #1d4ed8;
  --color-surface: #ffffff;
  --color-background: #f8fafc;
  --color-surface-hover: #f1f5f9;
  --color-text: #1e293b;
  --color-text-secondary: #64748b;
  --color-border: #e2e8f0;
  --color-divider: #e2e8f0;
  --space-1: 4px;
  --space-2: 8px;
  --space-3: 12px;
  --space-4: 16px;
  --space-6: 24px;
  --radius-lg: 8px;
  --font-size-sm: 14px;
  --font-size-md: 16px;
  --font-size-lg: 18px;
  --font-size-xl: 20px;
  --font-weight-medium: 500;
  --font-weight-bold: 700;

  /* フォーム入力（4b 用・Material なし） */
  --color-input-focus: var(--color-primary);
  --color-input-hover: #94a3b8;
  --color-input-arrow: var(--color-text-secondary);
  --shadow-input-focus: 0 0 0 2px rgba(37, 99, 235, 0.2);
  --form-textarea-min-height: 80px;
}
```

---

## 6. トースト（エラー・成功）

エラー・成功メッセージはトーストで統一する。画面内の `control.error` は使わず、Presenter の `onError` / 成功時にトーストを表示する。

### Material 利用時（MatSnackBar）

```typescript
// サービス例（MatSnackBar を注入）
@Injectable({ providedIn: 'root' })
export class ToastService {
  private readonly snackBar = inject(MatSnackBar);

  showError(message: string, duration = 5000): void {
    this.snackBar.open(message, undefined, {
      duration,
      panelClass: ['toast-error']  // テーマで --color-error 背景を指定
    });
  }

  showSuccess(message: string, duration = 3000): void {
    this.snackBar.open(message, undefined, { duration });
  }
}
```

Presenter の `onError` でトーストを表示する。

```typescript
onError(dto: ErrorDto): void {
  if (!this.view) throw new Error('Presenter: view not set');
  this.view.control = { ...this.view.control, loading: false };
  this.toast.showError(dto.message);
}
```

- View の `control.error` は廃止し、`loading: false` のみ更新する。
- エラー時もトーストでメッセージを表示するため、画面上部のインラインエラー表示（`master-error`）は不要になる。

### CDK のみの時（自前トースト）

既存の `UndoToastService` と同様に、エラー・成功用の「メッセージ＋数秒で閉じる」トーストを 1 コンポーネントで表示する。

- 状態: `{ visible: boolean, message: string, type: 'error' | 'success' }`
- 表示: 画面上部または下部に固定。`type === 'error'` のときは `--color-error` で背景または枠を付ける。
- 自動で 3〜5 秒後に `visible = false`。Undo 用は既存の `app-undo-toast` のまま別コンポーネントでよい。

### スタイル（自前トースト用）

```css
.toast-message {
  padding: var(--space-3) var(--space-4);
  border-radius: var(--radius-md);
  font-size: var(--font-size-sm);
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.12);
}
.toast-message--error {
  background: var(--color-error);
  color: var(--color-text-on-primary, #fff);
}
.toast-message--success {
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  color: var(--color-text);
}
```

---

## 7. 登録・編集画面テンプレート（一般構造・カード・レスポンシブ・スマホ）

登録・編集画面で共通して使う一般構造・カードの役割・レスポンシブ・スマホで操作しやすくするルールとサンプル。

**1列を基本**: フォーム内のフィールドは縦並び1列のみとし、複数列レイアウトにしない。

### 7a. 一般構造（HTML スケルトン）

登録・編集で共通して使う構造。一覧・詳細と違う点は、**フォーム送信と「戻る」などのアクションが `form-card__actions` にまとまる**こと。

**カードの中央配置**: `form-card` / `detail-card` はワイドスクリーンで左寄せだと右に広い余白が残るため、**中央配置**を推奨する。`page-main` に `display: flex; flex-direction: column; align-items: center;` を指定するか、カードに `margin-inline: auto` を付与する。

```html
<main class="page-main">
  <section class="form-card" aria-labelledby="form-heading">
    <h2 id="form-heading" class="form-card__title">新規登録 / 編集</h2>
    @if (control.loading) {
      <p class="master-loading">Loading...</p>
    } @else {
      <form (ngSubmit)="onSubmit()" #f="ngForm" class="form-card__form">
        <label class="form-card__field">
          ラベル
          <input name="field1" [(ngModel)]="control.formData.field1" required />
        </label>
        <!-- 必要に応じて form-card__field を追加 -->
        <div class="form-card__actions">
          <button type="submit" class="btn-primary" [disabled]="f.invalid || control.saving">保存</button>
          <a routerLink="/list" class="btn-secondary">戻る</a>
        </div>
      </form>
    }
  </section>
</main>
```

- `page-main`: ページ全体のラッパー。カードを中央に寄せる場合は `display: flex; flex-direction: column; align-items: center;` を付与。
- `form-card`: 1 画面に 1 枚。見出し・ローディング or フォーム・アクションを内包。`max-width` で幅を制限し、親の `align-items: center` で中央寄せされる。
- `form-card__title`: 画面の見出し（新規登録 / 編集など）。
- `form-card__form` + `form-card__field` + `form-card__actions`: フォーム本体と送信・戻るボタン。

### 7b. カードの役割

- **form-card**: 1 画面 1 枚で「この画面のフォーム全体」を包む。見出し・フォーム・アクションを内包する。
- **サブセクションが必要な場合**: フォーム内に `section-card` をネストして、グループごとに見出しを付ける。

```html
<form class="form-card__form">
  <label class="form-card__field">...</label>
  <section class="section-card" aria-labelledby="sub-heading">
    <h3 id="sub-heading" class="section-title">サブセクション見出し</h3>
    <label class="form-card__field">...</label>
  </section>
  <div class="form-card__actions">...</div>
</form>
```

### 7c. レスポンシブ

余白・幅はブレークポイント（[DESIGN_TOKENS.md の 7. レスポンシブ](DESIGN_TOKENS.md)）とトークンで調整する。メディアクエリの値は DESIGN_TOKENS の `--breakpoint-md`（768px）等と一致させる（CSS では変数が使えないため、コメントで `/* --breakpoint-md */` のように対応関係を書いておくとよい）。

**page-main**:  padding に加え、カード中央配置のため `display: flex; flex-direction: column; align-items: center;` を指定する。

```css
.page-main {
  padding: var(--space-4) var(--space-6);
  background: var(--color-background);
  min-height: 100vh;
  display: flex;
  flex-direction: column;
  align-items: center;
}

@media (max-width: 768px) { /* --breakpoint-md */
  .page-main {
    padding: var(--space-4);
  }
}
```

**form-card・detail-card の幅**: 幅制限なし。`width: 100%` のみで、一覧画面と同様に利用可能な幅を使う。

```css
.form-card,
.detail-card {
  width: 100%;
  background: var(--color-surface);
  border-radius: var(--radius-lg);
  padding: var(--space-4);
  border: 1px solid var(--color-border);
  box-shadow: var(--shadow-card);
}
```

小画面で form-card の padding を少し詰めてもよい。

```css
@media (max-width: 480px) { /* --breakpoint-sm */
  .form-card {
    padding: var(--space-3);
  }
}
```

**フォーム入力のはみ出し防止**: `.form-card__field` 配下の `input` / `textarea` / `select` に **`box-sizing: border-box`** を必ず指定する。`width: 100%` と padding・border を併用する場合、省略すると横にはみ出る。

```css
.form-card__field input,
.form-card__field textarea,
.form-card__field select {
  box-sizing: border-box;
  width: 100%;
  /* 他のスタイル（padding, border 等） */
}
```

### 7d. スマホで操作しやすくする

- **タップ領域**: ボタン・戻るリンクに `min-height: var(--touch-target-min)`（44px）と十分な padding を指定する。[DESIGN_TOKENS.md の 8. タッチ・操作](DESIGN_TOKENS.md)を参照。

```css
.btn-primary,
.btn-secondary {
  min-height: var(--touch-target-min);
  padding: var(--space-2) var(--space-4);
  display: inline-flex;
  align-items: center;
  justify-content: center;
}
```

- **入力欄**: iOS でフォーカス時の自動ズームを防ぐため、入力欄の `font-size` は 16px 以上を推奨する（`--font-size-md` を 16px にしておく）。
- **余白**: フィールド間は `gap: var(--space-4)` を維持し、小画面では `form-card` の padding を `var(--space-3)` にしてもよい（7c の例を参照）。
- **アクションを sticky にする（任意）**: フォームが長いとき、保存・戻るボタンを画面下部に固定するとスクロール後も操作しやすい。

```css
.form-card__actions {
  display: flex;
  gap: var(--space-2);
  padding-top: var(--space-2);
}

@media (max-width: 768px) {
  .form-card__actions {
    position: sticky;
    bottom: 0;
    padding: var(--space-3) 0;
    margin: 0 calc(-1 * var(--space-4)) calc(-1 * var(--space-4));
    padding-left: var(--space-4);
    padding-right: var(--space-4);
    background: var(--color-surface);
    border-top: 1px solid var(--color-divider);
  }
}
```

（小画面で form-card の padding を `var(--space-3)` にしている場合は、`margin` / `padding` の値を `--space-3` に合わせる。）

---

## 参照

- トークン一覧・Material テーマ対応: [DESIGN_TOKENS.md](DESIGN_TOKENS.md)
- 本 SKILL のルール・チェックリスト: [../SKILL.md](../SKILL.md)
