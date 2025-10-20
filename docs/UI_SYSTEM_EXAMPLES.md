# UI System - 実装例集

実際のコード例を豊富に掲載したガイドです。

## 📦 基本的な使い方

### 成功・エラー通知

```javascript
// フォーム送信
document.getElementById('myForm').addEventListener('submit', async (e) => {
  e.preventDefault();
  
  const formData = new FormData(e.target);
  
  try {
    const response = await fetch('/api/save', {
      method: 'POST',
      body: formData
    });
    
    if (response.ok) {
      Notify.success('保存しました');
      e.target.reset();
    } else {
      const error = await response.json();
      Notify.error(`保存に失敗: ${error.message}`);
    }
  } catch (error) {
    Notify.error('通信エラーが発生しました');
    console.error(error);
  }
});
```

### 削除確認ダイアログ

```javascript
// 削除ボタン
document.querySelectorAll('.delete-button').forEach(button => {
  button.addEventListener('click', async (e) => {
    const itemId = e.target.dataset.itemId;
    const itemName = e.target.dataset.itemName;
    
    const result = await Dialog.confirm(
      `「${itemName}」を削除してもよろしいですか？\nこの操作は取り消せません。`,
      {
        title: '削除の確認',
        confirmText: '削除する',
        cancelText: 'キャンセル',
        danger: true
      }
    );
    
    if (result.action === 'confirm') {
      const loadingId = Loading.show('削除中...');
      
      try {
        await fetch(`/api/items/${itemId}`, { method: 'DELETE' });
        Loading.hide(loadingId);
        Notify.success('削除しました');
        
        // DOM から削除
        e.target.closest('.item-card').remove();
      } catch (error) {
        Loading.hide(loadingId);
        Notify.error('削除に失敗しました');
      }
    }
  });
});
```

### 入力ダイアログ

```javascript
// 圃場追加
document.getElementById('addFieldButton').addEventListener('click', async () => {
  // 圃場名を入力
  const nameResult = await Dialog.prompt('圃場名を入力してください', {
    title: '新しい圃場',
    placeholder: '例: 圃場4',
    defaultValue: '圃場4'
  });
  
  if (nameResult.action !== 'confirm' || !nameResult.value) {
    return; // キャンセル
  }
  
  // 面積を入力
  const areaResult = await Dialog.prompt('面積（㎡）を入力してください', {
    title: '圃場の面積',
    type: 'number',
    placeholder: '例: 1000',
    defaultValue: '100'
  });
  
  if (areaResult.action !== 'confirm' || !areaResult.value) {
    return; // キャンセル
  }
  
  // 登録処理
  const loadingId = Loading.show('圃場を追加中...');
  
  try {
    await fetch('/api/fields', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        name: nameResult.value,
        area: areaResult.value
      })
    });
    
    Loading.hide(loadingId);
    Notify.success(`圃場「${nameResult.value}」を追加しました`);
    location.reload();
  } catch (error) {
    Loading.hide(loadingId);
    Notify.error('圃場の追加に失敗しました');
  }
});
```

---

## 🔄 既存コードの移行例

### custom_gantt_chart.js の置き換え

#### Before（従来）

```javascript
// custom_gantt_chart.js の既存コード
function showLoadingOverlay(message = '最適化処理中...') {
  hideLoadingOverlay();
  
  const overlay = document.createElement('div');
  overlay.id = 'reoptimization-overlay';
  overlay.style.cssText = `
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    background-color: rgba(0, 0, 0, 0.5);
    display: flex;
    justify-content: center;
    align-items: center;
    z-index: 9999;
    cursor: not-allowed;
  `;
  
  const spinner = document.createElement('div');
  // ... 複雑な実装 ...
  
  overlay.appendChild(spinner);
  document.body.appendChild(overlay);
}

function hideLoadingOverlay() {
  const overlay = document.getElementById('reoptimization-overlay');
  if (overlay) {
    overlay.remove();
  }
}

// 使用箇所
async function reoptimize() {
  showLoadingOverlay('最適化処理中...');
  
  try {
    await fetch('/api/optimize', { method: 'POST' });
    hideLoadingOverlay();
    alert('最適化が完了しました'); // ❌ ネイティブalert
  } catch (error) {
    hideLoadingOverlay();
    alert('最適化に失敗しました'); // ❌ ネイティブalert
  }
}

// 削除確認
if (confirm('本当に削除しますか？')) { // ❌ ネイティブconfirm
  deleteCultivation(id);
}

// 圃場追加
const fieldName = prompt('圃場名を入力してください（例: 圃場4）', defaultFieldName); // ❌ ネイティブprompt
if (fieldName) {
  const fieldArea = prompt('面積（㎡）を入力してください', '100'); // ❌ ネイティブprompt
  if (fieldArea && !isNaN(fieldArea)) {
    addField(fieldName, fieldArea);
  }
}
```

#### After（新規）

```javascript
// custom_gantt_chart.js の新しいコード
// ✅ showLoadingOverlay(), hideLoadingOverlay() は削除（共通システムを使用）

// 使用箇所
async function reoptimize() {
  const loadingId = Loading.show('最適化処理中...'); // ✅ 共通Loading
  
  try {
    await fetch('/api/optimize', { method: 'POST' });
    Loading.hide(loadingId);
    Notify.success('最適化が完了しました'); // ✅ Toast通知
  } catch (error) {
    Loading.hide(loadingId);
    Notify.error('最適化に失敗しました'); // ✅ Toast通知
  }
}

// 削除確認
const result = await Dialog.confirm('本当に削除しますか？', { danger: true }); // ✅ モダンDialog
if (result.action === 'confirm') {
  deleteCultivation(id);
}

// 圃場追加
const nameResult = await Dialog.prompt('圃場名を入力してください', { // ✅ モダンDialog
  title: '圃場の追加',
  placeholder: '例: 圃場4',
  defaultValue: defaultFieldName
});

if (nameResult.action !== 'confirm' || !nameResult.value) return;

const areaResult = await Dialog.prompt('面積（㎡）を入力してください', {
  title: '圃場の面積',
  type: 'number',
  defaultValue: '100'
});

if (areaResult.action !== 'confirm' || !areaResult.value || isNaN(areaResult.value)) {
  Notify.error('有効な面積を入力してください'); // ✅ エラー通知
  return;
}

addField(nameResult.value, areaResult.value);
```

### crop_palette_drag.js の置き換え

#### Before（従来）

```javascript
// crop_palette_drag.js の既存コード
function showErrorMessage(message) {
  const existingError = document.getElementById('crop-palette-error-modal');
  if (existingError) {
    existingError.remove();
  }
  
  const modal = document.createElement('div');
  modal.id = 'crop-palette-error-modal';
  modal.style.cssText = `
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    background-color: rgba(0, 0, 0, 0.5);
    display: flex;
    justify-content: center;
    align-items: center;
    z-index: 10000;
  `;
  
  const modalContent = document.createElement('div');
  // ... 複雑な実装 ...
  
  modal.appendChild(modalContent);
  document.body.appendChild(modal);
  
  document.getElementById('error-modal-close-btn').addEventListener('click', () => {
    modal.remove();
  });
}

// 使用箇所
if (isNewCropType && existingCropTypes.size >= MAX_CROP_TYPES) {
  const errorMessage = `最大${MAX_CROP_TYPES}種類までしか追加できません`;
  alert(errorMessage); // ❌ または showErrorMessage(errorMessage);
  return;
}
```

#### After（新規）

```javascript
// crop_palette_drag.js の新しいコード
// ✅ showErrorMessage() は削除（共通システムを使用）

// 使用箇所
if (isNewCropType && existingCropTypes.size >= MAX_CROP_TYPES) {
  const errorMessage = `最大${MAX_CROP_TYPES}種類までしか追加できません\n現在の作物: ${Array.from(existingCropTypes).join('、')}`;
  
  // ✅ 軽量な通知
  Notify.error(errorMessage);
  
  // または
  // ✅ ダイアログで詳細表示
  await Dialog.alert(errorMessage, '作物種類の上限');
  
  return;
}
```

---

## 🎯 実践的なパターン

### パターン1: CRUD操作

```javascript
class CropManager {
  async create(cropData) {
    const loadingId = Loading.show('作物を追加中...');
    
    try {
      const response = await fetch('/api/crops', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(cropData)
      });
      
      if (!response.ok) throw new Error('Failed to create');
      
      Loading.hide(loadingId);
      Notify.success('作物を追加しました');
      return await response.json();
    } catch (error) {
      Loading.hide(loadingId);
      Notify.error('作物の追加に失敗しました');
      throw error;
    }
  }
  
  async update(cropId, cropData) {
    const loadingId = Loading.show('作物を更新中...');
    
    try {
      const response = await fetch(`/api/crops/${cropId}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(cropData)
      });
      
      if (!response.ok) throw new Error('Failed to update');
      
      Loading.hide(loadingId);
      Notify.success('作物を更新しました');
      return await response.json();
    } catch (error) {
      Loading.hide(loadingId);
      Notify.error('作物の更新に失敗しました');
      throw error;
    }
  }
  
  async delete(cropId, cropName) {
    const result = await Dialog.confirm(
      `「${cropName}」を削除しますか？\nこの操作は取り消せません。`,
      {
        title: '作物の削除',
        confirmText: '削除',
        danger: true
      }
    );
    
    if (result.action !== 'confirm') return false;
    
    const loadingId = Loading.show('作物を削除中...');
    
    try {
      const response = await fetch(`/api/crops/${cropId}`, {
        method: 'DELETE'
      });
      
      if (!response.ok) throw new Error('Failed to delete');
      
      Loading.hide(loadingId);
      Notify.success('作物を削除しました');
      return true;
    } catch (error) {
      Loading.hide(loadingId);
      Notify.error('作物の削除に失敗しました');
      return false;
    }
  }
}
```

### パターン2: 複数ステップの処理

```javascript
async function importCropsFromCSV(file) {
  // ステップ1: ファイル検証
  const loadingId = Loading.show('ファイルを検証中...');
  
  if (!file.name.endsWith('.csv')) {
    Loading.hide(loadingId);
    await Dialog.alert('CSVファイルを選択してください', 'ファイル形式エラー');
    return;
  }
  
  // ステップ2: アップロード
  Loading.updateMessage(loadingId, 'ファイルをアップロード中...', `${file.name}`);
  
  const formData = new FormData();
  formData.append('file', file);
  
  try {
    const response = await fetch('/api/crops/import', {
      method: 'POST',
      body: formData
    });
    
    const result = await response.json();
    
    // ステップ3: 処理中（プログレス表示）
    Loading.hide(loadingId);
    const progressId = Loading.showProgress('作物データを処理中...', 0);
    
    // プログレス更新（仮想的なポーリング）
    let progress = 0;
    const interval = setInterval(async () => {
      const status = await fetch(`/api/crops/import/${result.import_id}/status`);
      const statusData = await status.json();
      
      progress = statusData.progress;
      Loading.updateProgress(progressId, progress);
      
      if (progress >= 100) {
        clearInterval(interval);
        Loading.hide(progressId);
        
        Notify.success(`${statusData.imported_count}件の作物をインポートしました`, {
          action: {
            text: '詳細を表示',
            callback: () => window.location.href = '/crops'
          }
        });
      }
    }, 500);
    
  } catch (error) {
    Loading.hide(loadingId);
    Notify.error('インポートに失敗しました: ' + error.message);
  }
}
```

### パターン3: バリデーション付きフォーム

```javascript
async function submitFieldForm(formElement) {
  const formData = new FormData(formElement);
  const latitude = parseFloat(formData.get('latitude'));
  const longitude = parseFloat(formData.get('longitude'));
  
  // バリデーション
  if (isNaN(latitude) || isNaN(longitude)) {
    Notify.error('緯度・経度は数値で入力してください');
    return;
  }
  
  if (latitude < -90 || latitude > 90) {
    Notify.error('緯度は-90〜90の範囲で入力してください');
    return;
  }
  
  if (longitude < -180 || longitude > 180) {
    Notify.error('経度は-180〜180の範囲で入力してください');
    return;
  }
  
  // 送信
  const loadingId = Loading.show('圃場を保存中...');
  
  try {
    const response = await fetch('/api/fields', {
      method: 'POST',
      body: formData
    });
    
    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.message);
    }
    
    Loading.hide(loadingId);
    Notify.success('圃場を保存しました');
    
    // リダイレクト
    setTimeout(() => {
      window.location.href = '/fields';
    }, 1000);
    
  } catch (error) {
    Loading.hide(loadingId);
    Notify.error(`保存に失敗しました: ${error.message}`);
  }
}
```

### パターン4: 元に戻す操作

```javascript
class UndoableAction {
  constructor() {
    this.history = [];
  }
  
  async deleteCrop(cropId, cropData) {
    // 削除実行
    await fetch(`/api/crops/${cropId}`, { method: 'DELETE' });
    
    // 元に戻すアクションを保存
    this.history.push({ type: 'delete', id: cropId, data: cropData });
    
    // 通知（元に戻すボタン付き）
    Notify.snackbar('作物を削除しました', {
      type: 'success',
      duration: 8000,
      action: {
        text: '元に戻す',
        callback: () => this.undo()
      }
    });
  }
  
  async undo() {
    if (this.history.length === 0) return;
    
    const action = this.history.pop();
    
    if (action.type === 'delete') {
      const loadingId = Loading.show('元に戻しています...');
      
      try {
        await fetch('/api/crops', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(action.data)
        });
        
        Loading.hide(loadingId);
        Notify.success('削除を取り消しました');
        
        // リロードまたはDOM更新
        location.reload();
      } catch (error) {
        Loading.hide(loadingId);
        Notify.error('元に戻せませんでした');
      }
    }
  }
}

const undoManager = new UndoableAction();

// 使用例
document.querySelectorAll('.delete-crop-button').forEach(button => {
  button.addEventListener('click', async (e) => {
    const cropId = e.target.dataset.cropId;
    const cropData = JSON.parse(e.target.dataset.cropData);
    
    const result = await Dialog.confirm('この作物を削除しますか？', { danger: true });
    
    if (result.action === 'confirm') {
      await undoManager.deleteCrop(cropId, cropData);
    }
  });
});
```

---

## 🚀 高度な使い方

### リアルタイム進捗表示（WebSocket連携）

```javascript
async function optimizeWithRealTimeProgress(planId) {
  const loadingId = Loading.showProgress('最適化を開始しています...', 0);
  
  // WebSocket接続
  const ws = new WebSocket(`wss://example.com/optimize/${planId}`);
  
  ws.onmessage = (event) => {
    const data = JSON.parse(event.data);
    
    if (data.type === 'progress') {
      Loading.updateProgress(loadingId, data.progress, data.message);
    } else if (data.type === 'complete') {
      Loading.hide(loadingId);
      Notify.success('最適化が完了しました', {
        action: {
          text: '結果を表示',
          callback: () => window.location.href = `/plans/${planId}/result`
        }
      });
      ws.close();
    } else if (data.type === 'error') {
      Loading.hide(loadingId);
      Notify.error(`最適化に失敗しました: ${data.message}`);
      ws.close();
    }
  };
  
  ws.onerror = () => {
    Loading.hide(loadingId);
    Notify.error('通信エラーが発生しました');
  };
  
  // 最適化開始リクエスト
  await fetch(`/api/plans/${planId}/optimize`, { method: 'POST' });
}
```

### 連続ダイアログ（ウィザード形式）

```javascript
async function createPlanWizard() {
  // Step 1: 農場選択
  // （実際にはセレクトボックスをダイアログ内に表示するなど、より高度な実装が必要）
  const farmResult = await Dialog.prompt('農場IDを入力してください', {
    title: '計画作成 (1/3)',
    type: 'number'
  });
  
  if (farmResult.action !== 'confirm') return;
  
  // Step 2: 計画名
  const nameResult = await Dialog.prompt('計画名を入力してください', {
    title: '計画作成 (2/3)',
    defaultValue: `計画-${new Date().toISOString().split('T')[0]}`
  });
  
  if (nameResult.action !== 'confirm') return;
  
  // Step 3: 期間
  const periodResult = await Dialog.prompt('計画期間（日数）を入力してください', {
    title: '計画作成 (3/3)',
    type: 'number',
    defaultValue: '365'
  });
  
  if (periodResult.action !== 'confirm') return;
  
  // 作成実行
  const loadingId = Loading.show('計画を作成中...');
  
  try {
    const response = await fetch('/api/plans', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        farm_id: farmResult.value,
        name: nameResult.value,
        period_days: periodResult.value
      })
    });
    
    const plan = await response.json();
    
    Loading.hide(loadingId);
    Notify.success('計画を作成しました', {
      action: {
        text: '開く',
        callback: () => window.location.href = `/plans/${plan.id}`
      }
    });
  } catch (error) {
    Loading.hide(loadingId);
    Notify.error('計画の作成に失敗しました');
  }
}
```

---

## 📝 まとめ

これらのパターンを参考に、プロジェクト全体で統一的なUI通知システムを活用してください。

**移行のポイント:**
1. `alert()` → `Notify.error()` または `Dialog.alert()`
2. `confirm()` → `Dialog.confirm()`
3. `prompt()` → `Dialog.prompt()`
4. カスタムローディング → `Loading.show()` / `Loading.hide()`
5. カスタムエラーモーダル → `Notify.error()` または `Dialog.alert()`

統一されたUIで、ユーザー体験が大幅に向上します！

