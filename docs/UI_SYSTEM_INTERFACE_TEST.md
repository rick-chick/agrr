# UI System インターフェース互換性テスト

## 🧪 テストケース一覧

### Test 1: alert() → Notify.error() の互換性

#### 既存コード（同期的）
```javascript
alert('エラーが発生しました');
// 次の行に即座に進む
console.log('alert後の処理');
```

#### 新しいコード
```javascript
Notify.error('エラーが発生しました');
// 次の行に即座に進む
console.log('Notify後の処理');
```

#### 互換性チェック
- ✅ 同期的に実行される
- ✅ 戻り値なし（void）
- ✅ 関数の構造変更不要
- ✅ コールバック不要

**結論**: 🟢 **完全互換、そのまま置き換え可能**

---

### Test 2: confirm() → Dialog.confirm() の互換性

#### 既存コード（同期的）
```javascript
function deleteItem() {
  if (confirm('本当に削除しますか？')) {
    console.log('削除します');
    performDelete();
  } else {
    console.log('キャンセルしました');
  }
}
```

#### 新しいコード（非同期）
```javascript
async function deleteItem() {
  const result = await Dialog.confirm('本当に削除しますか？', { danger: true });
  if (result.action === 'confirm') {
    console.log('削除します');
    performDelete();
  } else {
    console.log('キャンセルしました');
  }
}
```

#### 必要な変更
1. 関数に `async` キーワードを追加
2. `confirm()` の前に `await` を追加
3. 戻り値を `result` オブジェクトに変更
4. 判定を `result.action === 'confirm'` に変更

#### 互換性チェック
- ⚠️ 非同期化が必要
- ⚠️ 戻り値の構造が変わる
- ✅ ロジックは同じ
- ✅ エラーハンドリング不要

**結論**: 🟡 **async化が必要だが、変更は単純**

---

### Test 3: prompt() → Dialog.prompt() の互換性

#### 既存コード（同期的、2段階）
```javascript
function addField() {
  const fieldName = prompt('圃場名を入力してください', '圃場1');
  if (!fieldName) {
    console.log('キャンセルされました');
    return;
  }
  
  const fieldArea = prompt('面積（㎡）を入力してください', '100');
  if (!fieldArea || isNaN(fieldArea)) {
    console.log('無効な入力');
    return;
  }
  
  console.log('圃場を追加:', fieldName, fieldArea);
  performAdd(fieldName, fieldArea);
}
```

#### 新しいコード（非同期）
```javascript
async function addField() {
  const nameResult = await Dialog.prompt('圃場名を入力してください', {
    defaultValue: '圃場1',
    title: '圃場の追加 (1/2)'
  });
  
  if (nameResult.action !== 'confirm' || !nameResult.value) {
    console.log('キャンセルされました');
    return;
  }
  
  const areaResult = await Dialog.prompt('面積（㎡）を入力してください', {
    defaultValue: '100',
    type: 'number',
    title: '圃場の追加 (2/2)'
  });
  
  if (areaResult.action !== 'confirm' || !areaResult.value || isNaN(areaResult.value)) {
    console.log('無効な入力');
    return;
  }
  
  console.log('圃場を追加:', nameResult.value, areaResult.value);
  performAdd(nameResult.value, areaResult.value);
}
```

#### 必要な変更
1. 関数に `async` キーワードを追加
2. `prompt()` の前に `await` を追加
3. 戻り値を `result` オブジェクトに変更
4. 判定を `result.action === 'confirm'` に変更
5. 値の取得を `result.value` に変更
6. オプションをオブジェクトで指定

#### 互換性チェック
- ⚠️ 非同期化が必要
- ⚠️ 戻り値の構造が大きく変わる
- ✅ ロジックは同じ
- ✅ UXが向上（タイトル表示、型指定可能）

**結論**: 🟡 **async化と戻り値の扱い方が変わるが、機能は向上**

---

### Test 4: showLoadingOverlay() → Loading.show() の互換性

#### 既存コード
```javascript
function performOptimization() {
  showLoadingOverlay('最適化処理中...');
  
  fetch('/api/optimize', { method: 'POST' })
    .then(response => response.json())
    .then(data => {
      hideLoadingOverlay();
      console.log('完了:', data);
    })
    .catch(error => {
      hideLoadingOverlay();
      alert('エラーが発生しました');
    });
}
```

#### 新しいコード（推奨パターン）
```javascript
async function performOptimization() {
  const loadingId = Loading.show('最適化処理中...');
  
  try {
    const response = await fetch('/api/optimize', { method: 'POST' });
    const data = await response.json();
    Loading.hide(loadingId);
    console.log('完了:', data);
    Notify.success('最適化が完了しました');
  } catch (error) {
    Loading.hide(loadingId);
    Notify.error('エラーが発生しました');
  }
}
```

#### 必要な変更
1. `showLoadingOverlay()` の戻り値を `loadingId` に格納
2. すべての `hideLoadingOverlay()` を `Loading.hide(loadingId)` に変更
3. エラーケースでも確実に `Loading.hide()` を呼ぶ
4. （推奨）async/await とtry-catchで可読性向上

#### 互換性チェック
- ✅ 同期的に実行可能
- ⚠️ IDの管理が必要
- ✅ 関数の構造変更は最小
- ✅ エラーハンドリングが改善される

**結論**: 🟢 **ほぼ互換、IDの管理を追加するだけ**

---

## 🎯 実際のコード箇所での検証

### 検証1: custom_gantt_chart.js の alert (240行目)

#### 既存コード
```javascript
if (data.status === 'error') {
  console.error('❌ 最適化に失敗しました:', data.message);
  
  // ローディングオーバーレイを非表示
  hideLoadingOverlay();
  reoptimizationInProgress = false;

  // エラーメッセージを表示
  alert(data.message || getI18nMessage('jsGanttOptimizationFailed', 'Optimization failed'));
  
  // 変更を元に戻す
  revertChanges();
}
```

#### 新しいコード
```javascript
if (data.status === 'error') {
  console.error('❌ 最適化に失敗しました:', data.message);
  
  // ローディングオーバーレイを非表示
  hideLoadingOverlay();
  reoptimizationInProgress = false;

  // エラーメッセージを表示
  Notify.error(data.message || getI18nMessage('jsGanttOptimizationFailed', 'Optimization failed'));
  
  // 変更を元に戻す
  revertChanges();
}
```

**変更点**: `alert(` → `Notify.error(` のみ  
**互換性**: ✅ 完全互換

---

### 検証2: custom_gantt_chart.js の confirm (1226行目)

#### 既存コード
```javascript
// 空の圃場は削除ボタンを表示
if (group.cultivations.length === 0 && ganttState.fieldGroups.length > 1) {
  const removeButton = createSVGElement('text', {
    // ... 省略 ...
  }, '🗑️');
  
  removeButton.addEventListener('click', (e) => {
    e.stopPropagation();
    
    const message = getI18nTemplate('jsGanttConfirmDeleteField', {field_name: group.fieldName}, `Delete ${group.fieldName}?\n(This field has no crops and can be deleted)`);
    if (confirm(message)) {
      removeField(group.fieldId);
    }
  });
  
  headerGroup.appendChild(removeButton);
}
```

#### 新しいコード
```javascript
// 空の圃場は削除ボタンを表示
if (group.cultivations.length === 0 && ganttState.fieldGroups.length > 1) {
  const removeButton = createSVGElement('text', {
    // ... 省略 ...
  }, '🗑️');
  
  removeButton.addEventListener('click', async (e) => {  // async追加
    e.stopPropagation();
    
    const message = getI18nTemplate('jsGanttConfirmDeleteField', {field_name: group.fieldName}, `Delete ${group.fieldName}?\n(This field has no crops and can be deleted)`);
    const result = await Dialog.confirm(message, { danger: true });  // await追加、戻り値変更
    if (result.action === 'confirm') {  // 判定変更
      removeField(group.fieldId);
    }
  });
  
  headerGroup.appendChild(removeButton);
}
```

**変更点**: 
1. イベントリスナーに `async` 追加
2. `confirm()` → `await Dialog.confirm()`
3. 戻り値の判定変更

**互換性**: ✅ イベントリスナーはasync対応可能

---

### 検証3: custom_gantt_chart.js の prompt (1657, 1663行目)

#### 既存コード
```javascript
function addField() {
  // デフォルト圃場名を生成
  const existingFieldNames = ganttState.fieldGroups.map(g => g.fieldName);
  let fieldNumber = ganttState.fieldGroups.length + 1;
  let defaultFieldName = `圃場${fieldNumber}`;
  while (existingFieldNames.includes(defaultFieldName)) {
    fieldNumber++;
    defaultFieldName = `圃場${fieldNumber}`;
  }
  console.log('📝 デフォルト圃場名:', defaultFieldName);
  
  const fieldName = prompt('圃場名を入力してください（例: 圃場4）', defaultFieldName);
  if (!fieldName) {
    console.log('⚠️ 圃場名が入力されなかったためキャンセル');
    return;
  }
  
  const fieldArea = prompt('面積（㎡）を入力してください', '100');
  if (!fieldArea) {
    console.log('⚠️ 面積が入力されなかったためキャンセル');
    return;
  }
  
  // バリデーション
  const area = parseFloat(fieldArea);
  if (isNaN(area) || area <= 0) {
    alert(getI18nMessage('jsGanttInvalidArea', 'Please enter a valid area'));
    console.error('❌ 無効な面積:', fieldArea);
    return;
  }
  
  // ... 以下、APIリクエスト処理 ...
}
```

#### 新しいコード
```javascript
async function addField() {  // async追加
  // デフォルト圃場名を生成
  const existingFieldNames = ganttState.fieldGroups.map(g => g.fieldName);
  let fieldNumber = ganttState.fieldGroups.length + 1;
  let defaultFieldName = `圃場${fieldNumber}`;
  while (existingFieldNames.includes(defaultFieldName)) {
    fieldNumber++;
    defaultFieldName = `圃場${fieldNumber}`;
  }
  console.log('📝 デフォルト圃場名:', defaultFieldName);
  
  const nameResult = await Dialog.prompt('圃場名を入力してください（例: 圃場4）', {
    title: '圃場の追加 (1/2)',
    defaultValue: defaultFieldName,
    placeholder: '例: 圃場4'
  });
  
  if (nameResult.action !== 'confirm' || !nameResult.value) {
    console.log('⚠️ 圃場名が入力されなかったためキャンセル');
    return;
  }
  
  const areaResult = await Dialog.prompt('面積（㎡）を入力してください', {
    title: '圃場の追加 (2/2)',
    type: 'number',
    defaultValue: '100',
    placeholder: '例: 1000'
  });
  
  if (areaResult.action !== 'confirm' || !areaResult.value) {
    console.log('⚠️ 面積が入力されなかったためキャンセル');
    return;
  }
  
  // バリデーション
  const area = parseFloat(areaResult.value);
  if (isNaN(area) || area <= 0) {
    Notify.error(getI18nMessage('jsGanttInvalidArea', 'Please enter a valid area'));
    console.error('❌ 無効な面積:', areaResult.value);
    return;
  }
  
  const fieldName = nameResult.value;
  const fieldArea = areaResult.value;
  
  // ... 以下、APIリクエスト処理（変更なし） ...
}
```

**変更点**: 
1. 関数に `async` 追加
2. 2つの `prompt()` を `await Dialog.prompt()` に変更
3. 戻り値の判定とvalue取得を変更
4. タイトルと型指定を追加（UX向上）

**互換性**: ✅ 関数全体の構造は維持、async化のみ

---

### 検証4: custom_gantt_chart.js の Loading (950, 1031行目など)

#### 既存コード
```javascript
function reoptimizeSchedule(cultivationId, fromFieldName, toFieldName, newStartDate) {
  // ... 前処理 ...
  
  // 視覚的フィードバック: ローディングオーバーレイを表示
  showLoadingOverlay();
  
  // APIリクエスト
  fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(params)
  })
  .then(response => response.json())
  .then(data => {
    if (data.status === 'success') {
      // ローディングオーバーレイを非表示
      hideLoadingOverlay();
      // ... 成功処理 ...
    } else if (data.status === 'error') {
      hideLoadingOverlay();
      alert(data.message);
    }
  })
  .catch(error => {
    hideLoadingOverlay();
    alert('通信エラーが発生しました');
  });
}
```

#### 新しいコード（推奨パターン）
```javascript
async function reoptimizeSchedule(cultivationId, fromFieldName, toFieldName, newStartDate) {
  // ... 前処理 ...
  
  // 視覚的フィードバック: ローディング表示
  const loadingId = Loading.show('最適化処理中...');
  
  try {
    // APIリクエスト
    const response = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(params)
    });
    
    const data = await response.json();
    
    if (data.status === 'success') {
      Loading.hide(loadingId);
      // ... 成功処理 ...
      Notify.success('最適化が完了しました');
    } else if (data.status === 'error') {
      Loading.hide(loadingId);
      Notify.error(data.message);
    }
  } catch (error) {
    Loading.hide(loadingId);
    Notify.error('通信エラーが発生しました');
    console.error(error);
  }
}
```

**変更点**: 
1. `showLoadingOverlay()` → `const loadingId = Loading.show()`
2. すべての `hideLoadingOverlay()` → `Loading.hide(loadingId)`
3. （推奨）async/awaitとtry-catchに変更

**互換性**: ✅ ID管理を追加するだけで動作

---

## 📊 互換性マトリックス

| 現在のAPI | 新しいAPI | 同期/非同期 | 戻り値の互換性 | 関数構造の変更 | 総合評価 |
|-----------|-----------|------------|--------------|--------------|---------|
| `alert()` | `Notify.error()` | 同期 → 同期 | ✅ void → void | 不要 | 🟢 完全互換 |
| `confirm()` | `Dialog.confirm()` | 同期 → **非同期** | ⚠️ boolean → object | async化必要 | 🟡 要変更 |
| `prompt()` | `Dialog.prompt()` | 同期 → **非同期** | ⚠️ string → object | async化必要 | 🟡 要変更 |
| `showLoadingOverlay()` | `Loading.show()` | 同期 → 同期 | ⚠️ void → string | ID管理必要 | 🟢 ほぼ互換 |

---

## ✅ 結論

### 完全互換（即座に置き換え可能）
- ✅ `alert()` → `Notify.error()` - **13箇所**
- ✅ `showLoadingOverlay()` → `Loading.show()` - **ID管理のみ追加**

### 要変更（async化が必要）
- ⚠️ `confirm()` → `Dialog.confirm()` - **3箇所**
- ⚠️ `prompt()` → `Dialog.prompt()` - **2箇所**

### 推奨アプローチ
1. **Phase 1**: `alert()` を一括置換（最も簡単、即効性あり）
2. **Phase 2**: `Loading` を置換（ID管理を追加）
3. **Phase 3**: `confirm()` を個別に置換（async化）
4. **Phase 4**: `prompt()` を個別に置換（async化、UX改善）

**全体的な評価**: 🟢 **置き換え可能、段階的に実施すれば安全**

