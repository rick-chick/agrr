# SVGDragUtils 移行例

## custom_gantt_chart.js のリファクタリング例

### 現在のコード（Before）

```javascript
// グローバルなドラッグハンドラーを設定
function setupGlobalDragHandlers(svg, config, planStartDate, totalDays, chartWidth) {
  const dragThreshold = 5;
  
  // SVGの座標変換用
  let svgElement = svg;
  let initialMouseSvgOffset = { x: 0, y: 0 };
  
  // スクリーン座標をSVG座標に変換するヘルパー関数
  function screenToSVGCoords(svgElem, screenX, screenY) {
    if (!svgElem) return { x: screenX, y: screenY };
    const pt = svgElem.createSVGPoint();
    pt.x = screenX;
    pt.y = screenY;
    const ctm = svgElem.getScreenCTM();
    if (ctm) {
      return pt.matrixTransform(ctm.inverse());
    }
    return { x: screenX, y: screenY };
  }
  
  // ... 複雑なドラッグロジック（100行以上）
}
```

### リファクタリング後（After）

```javascript
// グローバルなドラッグハンドラーを設定（SVGDragUtilsを使用）
function setupGlobalDragHandlers(svg, config, planStartDate, totalDays, chartWidth) {
  // ドラッグマネージャーを作成
  const dragManager = new window.SVGDragManager(svg, {
    dragThreshold: 5,
    draggingClass: 'dragging',
    
    onDragStart: (element, state) => {
      console.log('ドラッグ開始');
      
      // 要素キャッシュを作成
      const cache = new window.ElementCache();
      cache.setMultiple({
        bg: '.bar-bg',
        label: '.bar-label',
        deleteBtn: '.delete-btn circle',
        deleteBtnText: '.delete-btn text'
      }, element);
      
      // ビジュアル効果
      const bg = cache.get('bg');
      if (bg) {
        bg.style.cursor = 'grabbing';
        bg.setAttribute('opacity', '0.8');
        bg.setAttribute('stroke-width', '4');
        bg.setAttribute('stroke-dasharray', '5,5');
      }
      
      // キャッシュを保存（グローバルスコープまたはクロージャー）
      element._cache = cache;
      element._originalFieldIndex = ganttState.originalFieldIndex;
    },
    
    onDrag: (element, state) => {
      const cache = element._cache;
      if (!cache) return;
      
      // 子要素の位置を更新
      const bg = cache.get('bg');
      const label = cache.get('label');
      const deleteBtn = cache.get('deleteBtn');
      const deleteBtnText = cache.get('deleteBtnText');
      
      if (bg) {
        const barWidth = parseFloat(bg.getAttribute('width'));
        const barHeight = parseFloat(bg.getAttribute('height'));
        
        // ラベル位置を更新
        if (label) {
          label.setAttribute('x', state.newX + (barWidth / 2));
          label.setAttribute('y', state.newY + (barHeight / 2) + 5);
        }
        
        // 削除ボタン位置を更新
        if (deleteBtn && deleteBtnText) {
          const btnX = state.newX + barWidth - 10;
          const btnY = state.newY + 10;
          deleteBtn.setAttribute('cx', btnX);
          deleteBtn.setAttribute('cy', btnY);
          deleteBtnText.setAttribute('x', btnX);
          deleteBtnText.setAttribute('y', btnY + 5);
        }
      }
      
      // ハイライト表示の更新
      updateFieldHighlight(state.newY, element._originalFieldIndex);
    },
    
    onDragEnd: (element, state) => {
      const cache = element._cache;
      
      // ビジュアルをリセット
      const bg = cache?.get('bg');
      if (bg) {
        bg.style.cursor = 'grab';
        bg.setAttribute('opacity', '0.95');
        bg.setAttribute('stroke-width', '2.5');
        bg.removeAttribute('stroke-dasharray');
      }
      
      // 新しい位置を計算して保存
      const newFieldIndex = calculateFieldIndex(state.newY);
      const newStartDate = calculateStartDate(state.newX);
      
      // サーバーに送信
      recordMove(element.getAttribute('data-id'), newFieldIndex, newStartDate);
      
      // キャッシュをクリア
      if (cache) {
        cache.clear();
        delete element._cache;
      }
    }
  });
  
  // ハイライトマネージャーを作成
  const highlightManager = new window.SVGHighlightManager(svg, {
    fill: '#FFEB3B',
    opacity: 0.4
  });
  
  // ヘルパー関数
  function updateFieldHighlight(newY, originalFieldIndex) {
    const ROW_HEIGHT = 70;
    const HEADER_HEIGHT = 60;
    
    const deltaY = newY - (HEADER_HEIGHT + originalFieldIndex * ROW_HEIGHT + 10);
    const fieldIndexChange = Math.round(deltaY / ROW_HEIGHT);
    const targetFieldIndex = Math.max(0, Math.min(
      originalFieldIndex + fieldIndexChange,
      ganttState.fieldGroups.length - 1
    ));
    
    if (targetFieldIndex !== originalFieldIndex) {
      const highlightY = HEADER_HEIGHT + (targetFieldIndex * ROW_HEIGHT);
      highlightManager.show(0, highlightY, config.width, ROW_HEIGHT);
    } else {
      highlightManager.hide();
    }
  }
  
  return { dragManager, highlightManager };
}
```

## 削減されるコード量

### Before（現在）
- `setupGlobalDragHandlers`: 約200行
- `screenToSVGCoords`: 約15行
- ハイライト管理: 約30行
- 要素キャッシュ: インラインで分散

**合計: 約245行**

### After（ユーティリティ使用後）
- `setupGlobalDragHandlers`: 約80行
- ユーティリティインポート: 既存

**合計: 約80行**

**削減率: 67%の削減**

## メリット

### 1. コードの簡潔化
- 複雑な座標変換ロジックを隠蔽
- ボイラープレートコードを削減
- 可読性の向上

### 2. 再利用性
- 他のSVGドラッグ機能でも使える
- crop_palette_drag.jsでも使える
- 新しい機能追加が容易

### 3. メンテナンス性
- バグ修正が一箇所で済む
- テストが容易
- 機能拡張がしやすい

### 4. パフォーマンス
- ユーティリティ内で最適化済み
- 要素キャッシュで高速化
- ハイライト要素の再利用

## 移行手順

### ステップ1: ユーティリティの読み込み確認

全てのレイアウトファイルに追加済み：
```erb
<%= javascript_include_tag "svg_drag_utils", "data-turbo-track": "reload", defer: true %>
```

### ステップ2: custom_gantt_chart.js のリファクタリング

1. `setupGlobalDragHandlers`関数を上記の例に置き換え
2. `screenToSVGCoords`関数を削除（ユーティリティを使用）
3. ハイライト管理をSVGHighlightManagerに置き換え

### ステップ3: crop_palette_drag.js のリファクタリング

同様のパターンでリファクタリング可能

### ステップ4: テスト

- `test/system/gantt_drag_drop_e2e_test.rb` を実行
- `test/system/crop_palette_real_test.rb` を実行
- ブラウザで動作確認

## 注意事項

### タイミング
`svg_drag_utils.js`は`defer`で読み込まれるため、DOMContentLoaded後に利用可能になります：

```javascript
document.addEventListener('DOMContentLoaded', () => {
  if (typeof window.SVGDragManager !== 'undefined') {
    // ユーティリティ使用可能
    setupDrag();
  }
});
```

### Turbo対応
Turboを使用している場合：

```javascript
document.addEventListener('turbo:load', () => {
  if (typeof window.SVGDragManager !== 'undefined') {
    setupDrag();
  }
});
```

## 今後の拡張案

### 1. スナップ機能
```javascript
const dragManager = new SVGDragManager(svg, {
  snapToGrid: true,
  gridSize: 10
});
```

### 2. 制約条件
```javascript
const dragManager = new SVGDragManager(svg, {
  constrainToParent: true,
  minX: 0,
  maxX: 1000
});
```

### 3. マルチタッチ対応
```javascript
const dragManager = new SVGDragManager(svg, {
  supportTouch: true
});
```

## 関連ドキュメント

- [SVG_DRAG_UTILS.md](./SVG_DRAG_UTILS.md) - API詳細ドキュメント
- [ASSET_MANAGEMENT.md](../ASSET_MANAGEMENT.md) - アセット管理ガイド

