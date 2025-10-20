# UI System 実行計画 - 段階的な移行手順

## 📋 実行サマリー

| Phase | 対象 | 箇所数 | 推定時間 | 難易度 | 優先度 |
|-------|------|--------|---------|--------|--------|
| Phase 1A | alert() - crop_palette_drag.js | 2箇所 | 5分 | ⭐ | 最高 |
| Phase 1B | alert() - fields.js | 3箇所 | 5分 | ⭐ | 高 |
| Phase 1C | alert() - custom_gantt_chart.js | 10箇所 | 10分 | ⭐ | 高 |
| Phase 2A | Loading - crop_palette_drag.js | 6箇所 + 関数削除 | 20分 | ⭐⭐ | 中 |
| Phase 2B | Loading - custom_gantt_chart.js | 10箇所 + 関数削除 | 30分 | ⭐⭐ | 中 |
| Phase 3 | confirm() - custom_gantt_chart.js | 3箇所 | 20分 | ⭐⭐ | 中 |
| Phase 4 | prompt() - custom_gantt_chart.js | 2箇所 | 20分 | ⭐⭐ | 低 |

**合計推定時間**: 約2時間

---

## 🎯 Phase 1A: alert() 置き換え - crop_palette_drag.js

### 対象
- 2箇所の `alert()` を `Notify.error()` に置き換え

### 具体的な変更

#### 変更1: 443行目
```javascript
// Before
if (typeof ganttState === 'undefined' || !ganttState.cultivation_plan_id) {
  alert(getI18nMessage('cropPalettePlanIdMissing', 'Error: Could not retrieve plan ID'));
  return;
}

// After
if (typeof ganttState === 'undefined' || !ganttState.cultivation_plan_id) {
  Notify.error(getI18nMessage('cropPalettePlanIdMissing', 'Error: Could not retrieve plan ID'));
  return;
}
```

#### 変更2: 480行目
```javascript
// Before
if (isNewCropType && existingCropTypes.size >= MAX_CROP_TYPES) {
  const errorMessage = getI18nTemplate(...);
  console.warn('⚠️ [CROP LIMIT] 作物種類が上限に達しています');
  alert(errorMessage);
  return;
}

// After
if (isNewCropType && existingCropTypes.size >= MAX_CROP_TYPES) {
  const errorMessage = getI18nTemplate(...);
  console.warn('⚠️ [CROP LIMIT] 作物種類が上限に達しています');
  Notify.error(errorMessage);
  return;
}
```

### テスト方法
1. 計画IDが取得できない状況を作る → Toast表示確認
2. 作物種類を上限まで追加してエラー発生 → Toast表示確認

### 完了条件
- [ ] 2箇所とも `Notify.error()` に変更
- [ ] ブラウザでToast通知が表示される
- [ ] コンソールエラーなし

---

## 🎯 Phase 1B: alert() 置き換え - fields.js

### 対象
- 3箇所の `alert()` を `Notify.error()` に置き換え

### 具体的な変更

#### 変更1: 296行目
```javascript
// Before
if (isNaN(lat) || isNaN(lng)) {
  e.preventDefault();
  alert(getI18nMessage('fieldsValidationCoordinatesNumeric', 'Latitude and longitude must be numeric values.'));
  return false;
}

// After
if (isNaN(lat) || isNaN(lng)) {
  e.preventDefault();
  Notify.error(getI18nMessage('fieldsValidationCoordinatesNumeric', 'Latitude and longitude must be numeric values.'));
  return false;
}
```

#### 変更2: 302行目
```javascript
// Before
if (lat < -90 || lat > 90) {
  e.preventDefault();
  alert(getI18nMessage('fieldsValidationLatitudeRange', 'Latitude must be between -90 and 90.'));
  return false;
}

// After
if (lat < -90 || lat > 90) {
  e.preventDefault();
  Notify.error(getI18nMessage('fieldsValidationLatitudeRange', 'Latitude must be between -90 and 90.'));
  return false;
}
```

#### 変更3: 308行目
```javascript
// Before
if (lng < -180 || lng > 180) {
  e.preventDefault();
  alert(getI18nMessage('fieldsValidationLongitudeRange', 'Longitude must be between -180 and 180.'));
  return false;
}

// After
if (lng < -180 || lng > 180) {
  e.preventDefault();
  Notify.error(getI18nMessage('fieldsValidationLongitudeRange', 'Longitude must be between -180 and 180.'));
  return false;
}
```

### テスト方法
1. 圃場フォームで無効な座標を入力 → Toast表示確認
2. 緯度範囲外の値を入力 → Toast表示確認
3. 経度範囲外の値を入力 → Toast表示確認

### 完了条件
- [ ] 3箇所とも `Notify.error()` に変更
- [ ] ブラウザでToast通知が表示される
- [ ] フォーム送信がブロックされる

---

## 🎯 Phase 1C: alert() 置き換え - custom_gantt_chart.js

### 対象
- 10箇所の `alert()` を `Notify.error()` に置き換え

### 具体的な変更

| 行 | Before | After | 用途 |
|----|--------|-------|------|
| 240 | `alert(data.message \|\| getI18nMessage('jsGanttOptimizationFailed', ...))` | `Notify.error(data.message \|\| getI18nMessage('jsGanttOptimizationFailed', ...))` | 最適化失敗 |
| 328 | `alert(getI18nMessage('jsGanttUpdateFailed', ...))` | `Notify.error(getI18nMessage('jsGanttUpdateFailed', ...))` | データ更新失敗 |
| 335 | `alert(getI18nMessage('jsGanttFetchError', ...))` | `Notify.error(getI18nMessage('jsGanttFetchError', ...))` | データ取得エラー |
| 816 | `alert(getI18nMessage('jsGanttFieldInfoError', ...))` | `Notify.error(getI18nMessage('jsGanttFieldInfoError', ...))` | 圃場情報エラー |
| 1006 | `alert(userMessage)` | `Notify.error(userMessage)` | 再最適化エラー |
| 1018 | `alert(getI18nMessage('jsGanttCommunicationError', ...))` | `Notify.error(getI18nMessage('jsGanttCommunicationError', ...))` | 通信エラー |
| 1671 | `alert(getI18nMessage('jsGanttInvalidArea', ...))` | `Notify.error(getI18nMessage('jsGanttInvalidArea', ...))` | バリデーションエラー |
| 1708 | `alert(data.message \|\| getI18nMessage('jsGanttFieldAddFailed', ...))` | `Notify.error(data.message \|\| getI18nMessage('jsGanttFieldAddFailed', ...))` | 圃場追加失敗 |
| 1714 | `alert(getI18nMessage('jsGanttCommunicationError', ...))` | `Notify.error(getI18nMessage('jsGanttCommunicationError', ...))` | 圃場追加通信エラー |
| 1756 | `alert(data.message \|\| getI18nMessage('jsGanttFieldDeleteFailed', ...))` | `Notify.error(data.message \|\| getI18nMessage('jsGanttFieldDeleteFailed', ...))` | 圃場削除失敗 |
| 1762 | `alert(getI18nMessage('jsGanttCommunicationError', ...))` | `Notify.error(getI18nMessage('jsGanttCommunicationError', ...))` | 圃場削除通信エラー |

### 一括置換コマンド（VS Code等）
```
検索: alert\(
置換: Notify.error(
```

### テスト方法
1. 最適化失敗ケースを発生させる
2. 圃場追加/削除エラーを発生させる
3. バリデーションエラーを発生させる
4. 通信エラーを発生させる（ネットワーク切断）

### 完了条件
- [ ] 10箇所とも `Notify.error()` に変更
- [ ] ブラウザでToast通知が表示される
- [ ] すべてのエラーケースでToast表示

---

## 🎯 Phase 2A: Loading置き換え - crop_palette_drag.js

### 対象
- `showLoadingOverlay()` / `hideLoadingOverlay()` の呼び出し箇所
- 関数定義の削除（561-630行）

### 具体的な変更

#### 変更1: 488-490行（ローディング開始）
```javascript
// Before
// ローディング表示
showLoadingOverlay();

// After
// ローディング表示
const loadingId = Loading.show('作物を追加中...');
```

#### 変更2: 535行（成功時のローディング終了）
```javascript
// Before
hideLoadingOverlay();

// After
Loading.hide(loadingId);
```

#### 変更3: 550行（エラー時のローディング終了）
```javascript
// Before
hideLoadingOverlay();

// After
Loading.hide(loadingId);
```

#### 変更4: 561-630行（関数定義削除）
```javascript
// 以下の関数定義を削除
function showLoadingOverlay(message = '最適化処理中...') { ... }
function hideLoadingOverlay() { ... }
```

### 注意点
- `loadingId` のスコープに注意（関数の先頭で宣言）
- try-catch-finally で確実に hide する

### テスト方法
1. 作物を追加 → ローディング表示確認
2. エラーケース → ローディングが消えるか確認

### 完了条件
- [ ] `showLoadingOverlay()` → `Loading.show()` に変更
- [ ] `hideLoadingOverlay()` → `Loading.hide(loadingId)` に変更
- [ ] 関数定義を削除
- [ ] ブラウザでローディング表示・非表示が動作
- [ ] 約70行削除

---

## 🎯 Phase 2B: Loading置き換え - custom_gantt_chart.js

### 対象
- `showLoadingOverlay()` / `hideLoadingOverlay()` の呼び出し箇所（10箇所以上）
- 関数定義の削除（1029-1095行）

### 具体的な変更

#### パターン1: reoptimizeSchedule() 関数（950行）
```javascript
// Before
function reoptimizeSchedule(...) {
  // ...
  showLoadingOverlay();
  
  fetch(...)
    .then(...)
    .then(data => {
      hideLoadingOverlay();
      // ...
    })
    .catch(error => {
      hideLoadingOverlay();
      // ...
    });
}

// After
async function reoptimizeSchedule(...) {  // async追加
  // ...
  const loadingId = Loading.show('最適化処理中...');
  
  try {
    const response = await fetch(...);
    const data = await response.json();
    Loading.hide(loadingId);
    // ...
  } catch (error) {
    Loading.hide(loadingId);
    // ...
  }
}
```

#### パターン2: addField() 関数（1679行）
```javascript
// Before
function addField() {
  // ...
  showLoadingOverlay(getI18nMessage('jsGanttAddingFieldLoading', 'Adding field...'));
  
  fetch(...)
    .then(...)
    .then(data => {
      // ...
      hideLoadingOverlay();
    })
    .catch(error => {
      hideLoadingOverlay();
    });
}

// After
async function addField() {  // async追加
  // ...
  const loadingId = Loading.show(getI18nMessage('jsGanttAddingFieldLoading', 'Adding field...'));
  
  try {
    const response = await fetch(...);
    const data = await response.json();
    // ...
    Loading.hide(loadingId);
  } catch (error) {
    Loading.hide(loadingId);
  }
}
```

#### 変更箇所一覧

| 行 | 関数 | 変更内容 |
|----|------|---------|
| 227, 236, 318, 329, 336 | `reoptimizeSchedule()` | 複数の `hideLoadingOverlay()` を `Loading.hide(loadingId)` に |
| 950 | `reoptimizeSchedule()` | `showLoadingOverlay()` を `const loadingId = Loading.show()` に |
| 1010, 1022 | エラーハンドリング | `hideLoadingOverlay()` を `Loading.hide(loadingId)` に |
| 1679 | `addField()` | `showLoadingOverlay()` を `const loadingId = Loading.show()` に |
| 1709, 1715 | `addField()` エラー | `hideLoadingOverlay()` を `Loading.hide(loadingId)` に |
| 1733 | `removeField()` | `showLoadingOverlay()` を `const loadingId = Loading.show()` に |
| 1757, 1763 | `removeField()` エラー | `hideLoadingOverlay()` を `Loading.hide(loadingId)` に |
| 1029-1095 | 関数定義 | 削除 |

### 注意点
- 関数を `async` 化する
- `.then()` チェーンを `async/await` に変更（推奨）
- try-catch-finally で確実に hide する

### テスト方法
1. ドラッグ&ドロップで最適化 → ローディング表示確認
2. 圃場追加 → ローディング表示確認
3. 圃場削除 → ローディング表示確認
4. エラーケース → ローディングが消えるか確認

### 完了条件
- [ ] すべての `showLoadingOverlay()` → `Loading.show()` に変更
- [ ] すべての `hideLoadingOverlay()` → `Loading.hide(loadingId)` に変更
- [ ] 関数定義を削除
- [ ] ブラウザでローディング表示・非表示が動作
- [ ] 約70行削除

---

## 🎯 Phase 3: confirm() 置き換え - custom_gantt_chart.js

### 対象
- 3箇所の `confirm()` を `Dialog.confirm()` に置き換え

### 具体的な変更

#### 変更1: 1226行（圃場削除確認）
```javascript
// Before
removeButton.addEventListener('click', (e) => {
  e.stopPropagation();
  
  const message = getI18nTemplate('jsGanttConfirmDeleteField', ...);
  if (confirm(message)) {
    removeField(group.fieldId);
  }
});

// After
removeButton.addEventListener('click', async (e) => {  // async追加
  e.stopPropagation();
  
  const message = getI18nTemplate('jsGanttConfirmDeleteField', ...);
  const result = await Dialog.confirm(message, {
    title: '圃場の削除',
    confirmText: '削除する',
    cancelText: 'キャンセル',
    danger: true
  });
  
  if (result.action === 'confirm') {
    removeField(group.fieldId);
  }
});
```

#### 変更2: 1394行（作物削除確認 - ダブルクリック）
```javascript
// Before
bar.addEventListener('dblclick', (e) => {
  e.stopPropagation();
  
  const message = getI18nTemplate('jsGanttConfirmDeleteCrop', ...);
  if (confirm(message)) {
    removeCultivation(cultivation.id);
  }
});

// After
bar.addEventListener('dblclick', async (e) => {  // async追加
  e.stopPropagation();
  
  const message = getI18nTemplate('jsGanttConfirmDeleteCrop', ...);
  const result = await Dialog.confirm(message, {
    title: '作物の削除',
    confirmText: '削除する',
    cancelText: 'キャンセル',
    danger: true
  });
  
  if (result.action === 'confirm') {
    removeCultivation(cultivation.id);
  }
});
```

#### 変更3: 1453行（作物削除確認 - 削除ボタン）
```javascript
// Before
removeButton.addEventListener('click', (e) => {
  e.stopPropagation();
  
  const message = getI18nTemplate('jsGanttConfirmDeleteCrop', ...);
  if (confirm(message)) {
    removeCultivation(cultivation.id);
  }
});

// After
removeButton.addEventListener('click', async (e) => {  // async追加
  e.stopPropagation();
  
  const message = getI18nTemplate('jsGanttConfirmDeleteCrop', ...);
  const result = await Dialog.confirm(message, {
    title: '作物の削除',
    confirmText: '削除する',
    cancelText: 'キャンセル',
    danger: true
  });
  
  if (result.action === 'confirm') {
    removeCultivation(cultivation.id);
  }
});
```

### テスト方法
1. 空の圃場の削除ボタンをクリック → ダイアログ表示確認
2. 作物バーをダブルクリック → ダイアログ表示確認
3. 作物の削除ボタンをクリック → ダイアログ表示確認
4. 「キャンセル」で削除されないか確認
5. 「削除する」で削除されるか確認

### 完了条件
- [ ] 3箇所とも `Dialog.confirm()` に変更
- [ ] イベントリスナーを `async` 化
- [ ] ダイアログが表示される
- [ ] キャンセル・確認の動作が正しい

---

## 🎯 Phase 4: prompt() 置き換え - custom_gantt_chart.js

### 対象
- 2箇所の `prompt()` を `Dialog.prompt()` に置き換え（addField() 関数内）

### 具体的な変更

#### 変更: 1657, 1663行（addField() 関数）
```javascript
// Before
function addField() {
  // デフォルト圃場名を生成
  const existingFieldNames = ganttState.fieldGroups.map(g => g.fieldName);
  let fieldNumber = ganttState.fieldGroups.length + 1;
  let defaultFieldName = `圃場${fieldNumber}`;
  while (existingFieldNames.includes(defaultFieldName)) {
    fieldNumber++;
    defaultFieldName = `圃場${fieldNumber}`;
  }
  
  const fieldName = prompt('圃場名を入力してください（例: 圃場4）', defaultFieldName);
  if (!fieldName) {
    return;
  }
  
  const fieldArea = prompt('面積（㎡）を入力してください', '100');
  if (!fieldArea) {
    return;
  }
  
  const area = parseFloat(fieldArea);
  if (isNaN(area) || area <= 0) {
    alert(getI18nMessage('jsGanttInvalidArea', 'Please enter a valid area'));
    return;
  }
  
  // ... APIリクエスト処理 ...
}

// After
async function addField() {  // async追加
  // デフォルト圃場名を生成
  const existingFieldNames = ganttState.fieldGroups.map(g => g.fieldName);
  let fieldNumber = ganttState.fieldGroups.length + 1;
  let defaultFieldName = `圃場${fieldNumber}`;
  while (existingFieldNames.includes(defaultFieldName)) {
    fieldNumber++;
    defaultFieldName = `圃場${fieldNumber}`;
  }
  
  const nameResult = await Dialog.prompt('圃場名を入力してください', {
    title: '圃場の追加 (1/2)',
    defaultValue: defaultFieldName,
    placeholder: '例: 圃場4'
  });
  
  if (nameResult.action !== 'confirm' || !nameResult.value) {
    return;
  }
  
  const areaResult = await Dialog.prompt('面積（㎡）を入力してください', {
    title: '圃場の追加 (2/2)',
    type: 'number',
    defaultValue: '100',
    placeholder: '例: 1000'
  });
  
  if (areaResult.action !== 'confirm' || !areaResult.value) {
    return;
  }
  
  const fieldName = nameResult.value;
  const area = parseFloat(areaResult.value);
  if (isNaN(area) || area <= 0) {
    Notify.error(getI18nMessage('jsGanttInvalidArea', 'Please enter a valid area'));
    return;
  }
  
  // ... APIリクエスト処理（変更なし） ...
}
```

### テスト方法
1. 圃場追加ボタンをクリック
2. 圃場名入力ダイアログ表示確認
3. キャンセル → 処理中断確認
4. 圃場名入力 → 面積入力ダイアログ表示確認
5. キャンセル → 処理中断確認
6. 面積入力 → 圃場追加確認
7. 無効な面積 → Toast表示確認

### 完了条件
- [ ] 2箇所の `prompt()` を `Dialog.prompt()` に変更
- [ ] 関数を `async` 化
- [ ] 2段階ダイアログが表示される
- [ ] キャンセル・確認の動作が正しい
- [ ] バリデーションが動作する

---

## 📊 進捗チェックリスト

### Phase 1: alert() 置き換え（13箇所）
- [ ] Phase 1A: crop_palette_drag.js (2箇所) - 5分
- [ ] Phase 1B: fields.js (3箇所) - 5分
- [ ] Phase 1C: custom_gantt_chart.js (10箇所) - 10分

### Phase 2: Loading 置き換え（2ファイル）
- [ ] Phase 2A: crop_palette_drag.js - 20分
- [ ] Phase 2B: custom_gantt_chart.js - 30分

### Phase 3: confirm() 置き換え（3箇所）
- [ ] custom_gantt_chart.js (3箇所) - 20分

### Phase 4: prompt() 置き換え（2箇所）
- [ ] custom_gantt_chart.js (2箇所) - 20分

---

## ✅ 最終確認項目

### 機能テスト
- [ ] すべての alert がToastで表示される
- [ ] すべての confirm がDialogで表示される
- [ ] すべての prompt がDialogで表示される
- [ ] すべての Loading が正常に動作する
- [ ] エラーケースでも正常に動作する

### コード品質
- [ ] 約240行のコードが削除された
- [ ] コンソールエラーがない
- [ ] Lintエラーがない

### UX確認
- [ ] Toast が画面下部に表示される
- [ ] Dialog がスムーズに表示される
- [ ] Loading がスムーズに表示される
- [ ] ユーザー操作に支障がない

---

**実行準備完了！段階的に実施していきましょう。** 🚀

