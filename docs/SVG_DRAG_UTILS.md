# SVG Drag & Drop ユーティリティ

## 概要

`svg_drag_utils.js`は、SVG要素のドラッグ&ドロップ機能を実装するための再利用可能なユーティリティです。

## 主な機能

### 1. SVGDragManager
SVG座標系でのドラッグ&ドロップを管理します。

**特徴:**
- スクリーン座標→SVG座標の自動変換
- ドラッグ閾値による誤操作防止
- CSS transition無効化（draggingクラス）
- カスタムコールバック対応

### 2. SVGHighlightManager
ドラッグ時のハイライト表示を管理します。

**特徴:**
- ハイライト要素の再利用
- パフォーマンス最適化
- カスタマイズ可能なスタイル

### 3. ElementCache
DOM検索の最適化用キャッシュマネージャーです。

## 使用方法

### 基本的な使い方

```javascript
// SVG要素を取得
const svg = document.querySelector('svg');

// ドラッグマネージャーを作成
const dragManager = new SVGDragManager(svg, {
  dragThreshold: 5,
  draggingClass: 'dragging',
  onDragStart: (element, state) => {
    console.log('ドラッグ開始', element);
  },
  onDrag: (element, state) => {
    console.log('ドラッグ中', state.newX, state.newY);
  },
  onDragEnd: (element, state) => {
    console.log('ドラッグ終了', state);
  }
});

// 要素をドラッグ可能にする
const draggableRect = svg.querySelector('.draggable-rect');
dragManager.makeDraggable(draggableRect);
```

### カスタム位置取得・設定

```javascript
dragManager.makeDraggable(element, {
  // カスタム位置取得
  getPosition: (el) => ({
    x: parseFloat(el.getAttribute('cx')), // circleの場合はcx/cy
    y: parseFloat(el.getAttribute('cy'))
  }),
  
  // カスタム位置設定
  setPosition: (el, x, y) => {
    el.setAttribute('cx', x);
    el.setAttribute('cy', y);
  },
  
  // マウスダウン時のカスタム処理
  onMouseDown: (e, state) => {
    // カーソルを変更など
    element.style.cursor = 'grabbing';
  },
  
  // マウスムーブ時のカスタム処理  
  onMouseMove: (e, state) => {
    // ラベル位置を更新など
    updateLabel(state.newX, state.newY);
  },
  
  // マウスアップ時のカスタム処理
  onMouseUp: (e, state) => {
    // サーバーに保存など
    savePosition(state.newX, state.newY);
  }
});
```

### ハイライト表示

```javascript
// ハイライトマネージャーを作成
const highlightManager = new SVGHighlightManager(svg, {
  fill: '#FFEB3B',
  opacity: 0.4,
  className: 'drop-zone-highlight'
});

// ドラッグ中にハイライトを表示
dragManager = new SVGDragManager(svg, {
  onDrag: (element, state) => {
    // ドロップ可能なゾーンをハイライト
    const targetZone = getTargetZone(state.newY);
    if (targetZone) {
      highlightManager.show(
        0,                    // x
        targetZone.y,         // y
        svg.getAttribute('width'), // width
        targetZone.height     // height
      );
    }
  },
  onDragEnd: (element, state) => {
    highlightManager.hide();
  }
});
```

### 要素キャッシュの使用

```javascript
// キャッシュを作成
const cache = new ElementCache();

// 複数の要素をキャッシュ
const barGroup = svg.querySelector('.bar-group');
cache.setMultiple({
  background: '.bar-bg',
  label: '.bar-label',
  deleteBtn: '.delete-btn'
}, barGroup);

// キャッシュから要素を取得（高速）
const bg = cache.get('background');
const label = cache.get('label');
```

## ガントチャートでの使用例

```javascript
function setupGanttDrag(svg, cultivationBars) {
  const dragManager = new SVGDragManager(svg, {
    dragThreshold: 5,
    onDragStart: (element, state) => {
      // トランジション無効化（draggingクラスは自動付与）
      element.querySelector('.bar-bg').setAttribute('opacity', '0.8');
    },
    onDrag: (element, state) => {
      // 子要素（ラベル、ボタン）の位置も更新
      updateChildElements(element, state.newX, state.newY);
      
      // ドロップ先のハイライト
      updateHighlight(state.newY);
    },
    onDragEnd: (element, state) => {
      // 元の見た目に戻す
      element.querySelector('.bar-bg').setAttribute('opacity', '0.95');
      
      // 新しい位置を保存
      saveNewPosition(element, state.newX, state.newY);
    }
  });
  
  // 各栽培バーをドラッグ可能に
  cultivationBars.forEach(bar => {
    dragManager.makeDraggable(bar, {
      getPosition: (el) => {
        const bg = el.querySelector('.bar-bg');
        return {
          x: parseFloat(bg.getAttribute('x')),
          y: parseFloat(bg.getAttribute('y'))
        };
      },
      setPosition: (el, x, y) => {
        const bg = el.querySelector('.bar-bg');
        bg.setAttribute('x', x);
        bg.setAttribute('y', y);
      }
    });
  });
}
```

## CSS設定

draggingクラスでtransitionを無効化してください：

```css
.dragging,
.dragging * {
  transition: none !important;
}

.dragging .bar-bg {
  filter: none !important; /* フィルター効果も無効化 */
}
```

## API リファレンス

### SVGDragManager

#### コンストラクタ
```javascript
new SVGDragManager(svgElement, options)
```

**options:**
- `dragThreshold`: ドラッグと判定する移動ピクセル数（デフォルト: 5）
- `draggingClass`: ドラッグ中に追加するクラス名（デフォルト: 'dragging'）
- `onDragStart`: ドラッグ開始時のコールバック
- `onDrag`: ドラッグ中のコールバック
- `onDragEnd`: ドラッグ終了時のコールバック

#### メソッド

**screenToSVGCoords(screenX, screenY)**
- スクリーン座標をSVG座標に変換
- 戻り値: `{ x, y }`

**makeDraggable(element, config)**
- 要素をドラッグ可能にする
- config: 位置取得/設定のカスタマイズ

**destroy()**
- イベントリスナーをクリーンアップ

**getState()**
- 現在のドラッグ状態を取得

**isDragging()**
- ドラッグ中かどうかを返す

### SVGHighlightManager

#### コンストラクタ
```javascript
new SVGHighlightManager(svg, options)
```

**options:**
- `fill`: 塗りつぶし色（デフォルト: '#FFEB3B'）
- `opacity`: 透明度（デフォルト: 0.4）
- `className`: クラス名（デフォルト: 'highlight-zone'）

#### メソッド

**show(x, y, width, height)**
- ハイライトを表示

**hide()**
- ハイライトを非表示

**destroy()**
- ハイライト要素を削除

### ElementCache

#### メソッド

**set(key, selector, parent)**
- 要素をキャッシュに追加

**setMultiple(elements, parent)**
- 複数の要素を一括キャッシュ

**get(key)**
- キャッシュから要素を取得

**clear()**
- キャッシュをクリア

**delete(key)**
- 特定のキーを削除

## パフォーマンス最適化

### 1. CSS transitionの無効化
```css
.dragging { transition: none !important; }
```

### 2. 要素参照のキャッシュ
```javascript
const cache = new ElementCache();
```

### 3. ハイライト要素の再利用
```javascript
const highlight = new SVGHighlightManager(svg);
// show/hideで再利用
```

### 4. GPU加速
- SVG座標変換APIを使用（getScreenCTM）
- transformではなく属性直接更新

## トラブルシューティング

### マウスとカードの位置がずれる
→ `screenToSVGCoords`を使って座標変換を行っているか確認

### ドラッグが遅い/カクつく
→ `draggingClass`でtransitionが無効化されているか確認

### 子要素の位置がずれる
→ `onDrag`で子要素の位置も更新しているか確認

## 互換性

- モダンブラウザ（ES6+）
- SVG 1.1以降
- Turbo対応

## ライセンス

プロジェクトのライセンスに従います。

