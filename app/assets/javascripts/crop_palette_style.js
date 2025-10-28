// app/assets/javascripts/crop_palette_style.js
// 作物パレットのカードにガントカードと同じ色を適用

function applyCropCardColors() {
  const cropCards = document.querySelectorAll('.crop-palette-card');
  
  // crop_colors.jsが読み込まれているかチェック
  if (typeof window.getCropColor === 'undefined') {
    console.warn('⚠️ crop_colors.js が読み込まれていません。色の適用をスキップします。');
    return;
  }
  
  cropCards.forEach(card => {
    const cropName = card.dataset.cropName;
    if (!cropName) return;
    
    const bar = card.querySelector('.crop-card-bar');
    if (!bar) return;
    
    // ミニマルリスト形式：左ボーダーに色を適用
    const strokeColor = window.getCropStrokeColor(cropName);
    
    // 左ボーダーのみに色を適用（ミニマルリスト形式）
    bar.style.borderLeftColor = strokeColor;
  });
  
  console.log(`✅ 作物カード ${cropCards.length} 枚に色を適用しました（ミニマルリスト形式）`);
}

// 初期化関数
function initCropPaletteStyle() {
  applyCropCardColors();
}

// 複数のタイミングで初期化を試行（重複を避けるためturbo:frame-renderのみ使用）
document.addEventListener('DOMContentLoaded', () => {
  initCropPaletteStyle();
});

// Turbo対応（重複を避けるためturbo:frame-renderのみ使用）
if (typeof Turbo !== 'undefined') {
  document.addEventListener('turbo:frame-render', () => {
    initCropPaletteStyle();
  });
}

// ガントチャートが準備完了した後も実行（色マップが初期化された後）
document.addEventListener('ganttChartReady', () => {
  console.log('📡 ganttChartReady イベントを受信、作物カードに色を適用中...');
  applyCropCardColors();
});

// 即座に試行（DOM要素が既に存在する場合）
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initCropPaletteStyle);
} else {
  // DOMが既に読み込まれている場合
  initCropPaletteStyle();
}

// 遅延初期化（フォールバック）
setTimeout(() => {
  initCropPaletteStyle();
}, 500);

// グローバルに公開
window.applyCropCardColors = applyCropCardColors;

