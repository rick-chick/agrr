// app/assets/javascripts/crop_palette_drag.js
// 作物パレットのドラッグ&ドロップ機能

// i18nヘルパー関数
function getI18nMessage(key, defaultMessage) {
  const i18nData = document.body.dataset;
  return i18nData[key] || defaultMessage;
}

function getI18nTemplate(key, replacements, defaultMessage) {
  let template = document.body.dataset[key] || defaultMessage;
  for (const [placeholder, value] of Object.entries(replacements)) {
    template = template.replace(placeholder, value);
  }
  return template;
}

// 初期化フラグ
// Turboページ遷移対応: すでに定義されている場合は再利用
if (typeof window.cropPaletteInitialized === 'undefined') {
  window.cropPaletteInitialized = false;
}
if (typeof window.ganttChartReady === 'undefined') {
  window.ganttChartReady = false;
}

// ガントチャート準備完了イベントをリッスン
document.addEventListener('ganttChartReady', () => {
  window.ganttChartReady = true;
  
  // ガントチャートの準備ができたら、作物パレットのドラッグ機能を初期化
  if (!window.cropPaletteInitialized) {
    // まだパレット自体が初期化されていない場合
    tryInitialize();
  } else {
    // パレットは初期化済みだが、ドラッグ機能がまだの場合
    initCropCardDrag();
    initGanttDropZone();
  }
});

// トグル関数
function toggleCropPalette() {
  const panel = document.getElementById('crop-palette-panel');
  const toggleBtn = document.getElementById('crop-palette-toggle');
  
  if (!panel) {
    return;
  }
  
  panel.classList.toggle('collapsed');
  
  // トグルボタンのアイコンも回転
  if (toggleBtn) {
    const icon = toggleBtn.querySelector('.toggle-icon');
    if (icon) {
      const isCollapsed = panel.classList.contains('collapsed');
      icon.style.transform = isCollapsed ? 'rotate(0deg)' : 'rotate(180deg)';
    }
  }
  
  // ローカルストレージに状態を保存
  const isCollapsed = panel.classList.contains('collapsed');
  localStorage.setItem('cropPaletteCollapsed', isCollapsed);
}

// 初期化関数
function initializeCropPalette() {
  const palettePanel = document.getElementById('crop-palette-panel');
  if (!palettePanel) {
    return;
  }

  // トグルボタンの設定（ガントチャート不要）
  setupToggleButton();
  
  // ガントチャートが準備できている場合のみドラッグ機能を初期化
  if (window.ganttChartReady) {
    // 作物カードのドラッグ設定
    initCropCardDrag();
    // ガントチャートのドロップゾーン
    initGanttDropZone();
  }
  
  window.cropPaletteInitialized = true;
}

// トグルボタンの設定
function setupToggleButton() {
  const toggleBtn = document.getElementById('crop-palette-toggle');
  const panel = document.getElementById('crop-palette-panel');
  
  if (!toggleBtn || !panel) {
    return;
  }

  // 既にイベントリスナーが設定されている場合はスキップ
  if (toggleBtn.dataset.listenerAdded === 'true') {
    return;
  }

  // クリックイベントを設定
  toggleBtn.addEventListener('click', function(e) {
    e.preventDefault();
    e.stopPropagation();
    toggleCropPalette();
  });

  // キーボードアクセシビリティ対応
  toggleBtn.addEventListener('keydown', function(e) {
    if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault();
      toggleCropPalette();
    }
  });

  // イベントリスナー設定済みフラグ
  toggleBtn.dataset.listenerAdded = 'true';

  // 保存された状態を復元
  const savedState = localStorage.getItem('cropPaletteCollapsed');
  
  if (savedState === 'true') {
    panel.classList.add('collapsed');
    
    // トグルボタンのアイコンも回転
    const icon = toggleBtn.querySelector('.toggle-icon');
    if (icon) {
      icon.style.transform = 'rotate(180deg)';
    }
  } else {
    // 初期状態では開いている（collapsedクラスを確実に削除）
    panel.classList.remove('collapsed');
    
    const icon = toggleBtn.querySelector('.toggle-icon');
    if (icon) {
      icon.style.transform = 'rotate(0deg)';
    }
  }
}

// 初期化関数
function tryInitialize() {
  if (!window.cropPaletteInitialized) {
    initializeCropPalette();
  }
}

// 複数のタイミングで初期化を試行
document.addEventListener('DOMContentLoaded', () => {
  tryInitialize();
});

// Turbo対応
if (typeof Turbo !== 'undefined') {
  document.addEventListener('turbo:load', () => {
    window.cropPaletteInitialized = false;
    tryInitialize();
  });
}

// 即座に試行（DOM要素が既に存在する場合）
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', tryInitialize);
} else {
  // DOMが既に読み込まれている場合
  tryInitialize();
}

// 遅延初期化（フォールバック）
setTimeout(() => {
  tryInitialize();
}, 500);


// SVG要素を作成するヘルパー関数（custom_gantt_chart.jsと同じ）
function createSVGElement(tag, attrs = {}, textContent = null) {
  const element = document.createElementNS('http://www.w3.org/2000/svg', tag);
  
  Object.entries(attrs).forEach(([key, value]) => {
    element.setAttribute(key, value);
  });
  
  if (textContent !== null) {
    element.textContent = textContent;
  }
  
  return element;
}

// 作物カードのドラッグ設定
function initCropCardDrag() {
  const cropCards = document.querySelectorAll('.crop-palette-card');
  console.log(`🌱 作物カード ${cropCards.length} 枚にドラッグ設定中...`);

  cropCards.forEach(card => {
    // 既にイベントリスナーが設定されている場合はスキップ
    if (card.dataset.dragInitialized === 'true') {
      console.log('⏭️  カードは既に初期化済み:', card.dataset.cropName);
      return;
    }
    
    let draggedSVGBar = null;
    let dragData = null;
    
    // mousedownでドラッグ開始
    card.addEventListener('mousedown', (e) => {
      console.log('🎯 [DRAG START] mousedownイベント発火:', card.dataset.cropName);
      e.preventDefault();
      
      // ドラッグデータを設定
      dragData = {
        crop_id: card.dataset.cropId,
        crop_name: card.dataset.cropName,
        crop_variety: card.dataset.cropVariety
      };
      
      console.log('🚀 ドラッグ開始:', dragData);
      
      // 視覚的フィードバック
      card.classList.add('dragging');
      
      // パレットを即座に閉じる
      const panel = document.getElementById('crop-palette-panel');
      if (panel && !panel.classList.contains('collapsed')) {
        toggleCropPalette();
        console.log('🔽 作物パレットを自動的に閉じました');
      }
      
      // SVGコンテナを取得
      const svgContainer = document.getElementById('gantt-chart-container');
      const svg = svgContainer ? svgContainer.querySelector('svg.custom-gantt-chart') : null;
      
      if (!svg) {
        console.warn('⚠️ SVGが見つかりません - ガントチャートが初期化されていない可能性があります');
        card.classList.remove('dragging');
        alert('ガントチャートの読み込みを待ってから再度お試しください');
        return;
      }
      
      // SVGバーを作成（custom_gantt_chart.jsと同じスタイル）
      const fillColor = typeof window.getCropColor !== 'undefined' 
        ? window.getCropColor(dragData.crop_name) 
        : '#9ae6b4';
      const strokeColor = typeof window.getCropStrokeColor !== 'undefined' 
        ? window.getCropStrokeColor(dragData.crop_name) 
        : '#48bb78';
      
      const barGroup = createSVGElement('g', {
        class: 'drag-preview-bar',
        'pointer-events': 'none',
        opacity: 0.9
      });
      
      const rect = createSVGElement('rect', {
        x: 0,
        y: 0,
        width: 120,
        height: 25,
        rx: 6,
        ry: 6,
        fill: fillColor,
        stroke: strokeColor,
        'stroke-width': 2.5,
        'stroke-dasharray': '5,5'
      });
      
      const text = createSVGElement('text', {
        x: 60,
        y: 16,
        'text-anchor': 'middle',
        fill: '#1F2937',
        'font-size': '10px',
        'font-weight': '600'
      }, dragData.crop_name);
      
      barGroup.appendChild(rect);
      barGroup.appendChild(text);
      svg.appendChild(barGroup);
      
      draggedSVGBar = barGroup;
      
      // マウス位置に追従（custom_gantt_chart.jsのグローバルハンドラーを真似る）
      const mouseMoveHandler = (moveEvent) => {
        if (!draggedSVGBar) return;
        
        // マウス座標をSVG座標に変換
        const svgPoint = svg.createSVGPoint();
        svgPoint.x = moveEvent.clientX;
        svgPoint.y = moveEvent.clientY;
        const svgCoords = svgPoint.matrixTransform(svg.getScreenCTM().inverse());
        
        // バーをマウス位置に移動（カーソルは左から5px、上下中央）
        const barX = svgCoords.x - 5;
        const barY = svgCoords.y - 12.5;
        
        draggedSVGBar.setAttribute('transform', `translate(${barX}, ${barY})`);
      };
      
      const mouseUpHandler = (upEvent) => {
        console.log('🏁 [DRAG END] mouseupイベント発火');
        console.log('🏁 [DRAG END] イベントタイムスタンプ:', new Date().toISOString());
        card.classList.remove('dragging');
        
        // SVGバーを削除
        if (draggedSVGBar && draggedSVGBar.parentNode) {
          draggedSVGBar.parentNode.removeChild(draggedSVGBar);
        }
        
        // ドロップ位置を計算
        const svgPoint = svg.createSVGPoint();
        svgPoint.x = upEvent.clientX;
        svgPoint.y = upEvent.clientY;
        const svgCoords = svgPoint.matrixTransform(svg.getScreenCTM().inverse());
        
        console.log('📍 [DROP] ドロップ位置計算:', { x: svgCoords.x, y: svgCoords.y });
        
        let dropInfo;
        try {
          dropInfo = calculateDropInfo(svgCoords);
          console.log('📍 [DROP] 計算結果:', dropInfo);
        } catch (error) {
          console.error('❌ [DROP] ドロップ位置計算エラー:', error);
          const errorMessage = getI18nMessage(
            'cropPaletteDropCalculationError',
            'ドロップ位置の計算中にエラーが発生しました。ページを再読み込みしてください。'
          );
          alert(errorMessage);
          return;
        }
        
        if (dropInfo) {
          console.log('✅ [DROP] ドロップ位置が有効 - addCropToSchedule呼び出し');
          // 作物を追加
          addCropToSchedule(dragData, dropInfo);
        } else {
          console.log('❌ [DROP] ドロップ位置が無効（範囲外）');
          // 表示範囲外へのドロップを拒否
          const errorMessage = getI18nMessage(
            'cropPaletteDropOutsideRange',
            '表示範囲外には作物を追加できません。表示範囲内にドロップしてください。'
          );
          alert(errorMessage);
        }
        
        // イベントリスナーを削除
        document.removeEventListener('mousemove', mouseMoveHandler);
        document.removeEventListener('mouseup', mouseUpHandler);
        
        draggedSVGBar = null;
        dragData = null;
      };
      
      // グローバルイベントリスナーを登録
      document.addEventListener('mousemove', mouseMoveHandler);
      document.addEventListener('mouseup', mouseUpHandler);
    });
    
    // 初期化済みフラグを設定
    card.dataset.dragInitialized = 'true';
    console.log('✅ カード初期化完了:', card.dataset.cropName);
  });
}

// ガントチャートのドロップゾーン設定（マウスイベントベースのため不要）
function initGanttDropZone() {
  // SVGへのドラッグ&ドロップはmousedownイベントで処理されるため、
  // HTML5 Drag&Drop APIのイベントリスナーは不要
  console.log('✅ マウスイベントベースのドラッグ&ドロップを使用');
}

// ドロップ位置から圃場と日付を計算
function calculateDropInfo(svgCoords) {
  // ganttStateはcustom_gantt_chart.jsで定義されている
  if (typeof window.ganttState === 'undefined' || !window.ganttState.config) {
    return null;
  }

  const ganttState = window.ganttState;
  const config = ganttState.config;
  const chartWidth = ganttState.chartWidth;

  // 表示範囲が設定されている場合は表示範囲を使用、なければ計画期間を使用（フォールバック）
  // 注: 表示範囲が未設定の場合は計画期間をフォールバックとして使用するが、
  //     通常は表示範囲が設定されているため、表示範囲を基準に計算する
  const displayStartDate = ganttState.displayStartDate || ganttState.planStartDate;
  const displayEndDate = ganttState.displayEndDate || ganttState.planEndDate;
  const fieldGroups = ganttState.fieldGroups;

  // 表示範囲の日数を計算（表示範囲が設定されている場合は表示範囲の日数、なければ計画期間の日数）
  const totalDays = daysBetween(displayStartDate, displayEndDate);

  // Y座標から圃場を判定
  const ROW_HEIGHT = 70;
  const HEADER_HEIGHT = config.margin.top;

  if (svgCoords.y < HEADER_HEIGHT) {
    return null;
  }

  const fieldIndex = Math.floor((svgCoords.y - HEADER_HEIGHT) / ROW_HEIGHT);

  if (fieldIndex < 0 || fieldIndex >= fieldGroups.length) {
    return null;
  }

  const targetField = fieldGroups[fieldIndex];

  // X座標から日付を計算
  const MARGIN_LEFT = config.margin.left;

  if (svgCoords.x < MARGIN_LEFT) {
    return null;
  }

  // 表示範囲の開始日を基準に日付を計算
  const daysFromDisplayStart = Math.round(((svgCoords.x - MARGIN_LEFT) / chartWidth) * totalDays);
  const startDate = new Date(displayStartDate);
  startDate.setDate(startDate.getDate() + daysFromDisplayStart);

  // 表示範囲のチェック
  const startDateStr = startDate.toISOString().split('T')[0];
  const displayStartDateStr = new Date(displayStartDate).toISOString().split('T')[0];
  const displayEndDateStr = new Date(displayEndDate).toISOString().split('T')[0];
  
  // 表示範囲外の場合はnullを返す（ドロップを拒否）
  if (startDateStr < displayStartDateStr || startDateStr > displayEndDateStr) {
    return null;
  }

  // field_idを正規化（window.normalizeFieldIdを使用）
  const normalizedFieldId = typeof window.normalizeFieldId === 'function' 
    ? window.normalizeFieldId(targetField.fieldId) 
    : targetField.fieldId;
  
  return {
    field_id: normalizedFieldId,
    field_name: targetField.fieldName,
    start_date: startDateStr
  };
}

// 2つの日付間の日数を計算（crop_palette_drag.js用のヘルパー関数）
function daysBetween(date1, date2) {
  const d1 = typeof date1 === 'string' ? new Date(date1) : date1;
  const d2 = typeof date2 === 'string' ? new Date(date2) : date2;
  
  // 無効な日付の場合はエラーを発生（異常系はフォールバックではなくエラーを上げる）
  if (isNaN(d1.getTime()) || isNaN(d2.getTime())) {
    throw new Error(`Invalid date in daysBetween: date1=${date1}, date2=${date2}, d1=${d1}, d2=${d2}`);
  }
  
  const oneDay = 24 * 60 * 60 * 1000;
  const result = Math.round(Math.abs((d2 - d1) / oneDay));
  
  // 結果が0以下の場合は最小値を返す（単一日の表示範囲でも座標計算が正しく動作するように）
  return Math.max(result, 1);
}

// 日付を ISO 形式 (YYYY-MM-DD) 文字列にフォーマット
function formatAsIsoDate(value) {
  if (!value) {
    return null;
  }
  const targetDate = typeof value === 'string' ? new Date(value) : value;
  if (!targetDate || isNaN(targetDate.getTime())) {
    console.warn('⚠️ formatAsIsoDate に無効な日付が渡されました:', value);
    return null;
  }
  return targetDate.toISOString().split('T')[0];
}

// 作物種類の上限
if (typeof window.MAX_CROP_TYPES === 'undefined') {
  window.MAX_CROP_TYPES = 5;
}

// リクエスト中フラグ（二重送信防止）
if (typeof window.isAddingCrop === "undefined") { window.isAddingCrop = false; }

// 作物をスケジュールに追加
function addCropToSchedule(cropData, dropInfo) {
  console.log('🚀 [ADD CROP] 関数呼び出し開始');
  console.log('🚀 [ADD CROP] cropData:', cropData);
  console.log('🚀 [ADD CROP] dropInfo:', dropInfo);
  
  // 二重送信防止チェック
  if (window.isAddingCrop) {
    console.warn('⚠️ [DUPLICATE REQUEST BLOCKED] 既にリクエスト処理中です');
    return;
  }
  
  // ganttStateから計画IDを取得
  if (typeof window.ganttState === 'undefined' || !window.ganttState.cultivation_plan_id) {
    alert(getI18nMessage('cropPalettePlanIdMissing', 'Error: Could not retrieve plan ID'));
    return;
  }

  const ganttState = window.ganttState;
  const cultivation_plan_id = ganttState.cultivation_plan_id;
  
  // 作物種類数の制限チェック（同じ作物の複数配置はOK）
  const existingCropTypes = new Set();
  if (ganttState.cultivationData && ganttState.cultivationData.length > 0) {
    ganttState.cultivationData.forEach(cultivation => {
      // 作物名の基本部分を取得（品種名を除く）
      const baseCropName = cultivation.crop_name.split('（')[0];
      existingCropTypes.add(baseCropName);
    });
  }
  
  // 新しく追加しようとしている作物の基本名
  const newCropBaseName = cropData.crop_name.split('（')[0];
  
  // 新しい作物種類かどうかを判定
  const isNewCropType = !existingCropTypes.has(newCropBaseName);
  
  console.log('🔍 [CROP CHECK] 既存の作物種類数:', existingCropTypes.size);
  console.log('🔍 [CROP CHECK] 既存の作物種類:', Array.from(existingCropTypes));
  console.log('🔍 [CROP CHECK] 新規作物:', newCropBaseName, '新しい種類:', isNewCropType);
  
  // 新しい作物種類を追加しようとしていて、すでに上限に達している場合
  if (isNewCropType && existingCropTypes.size >= window.MAX_CROP_TYPES) {
    const errorMessage = getI18nTemplate(
      'cropPaletteCropTypesLimit',
      {
        '__MAX_TYPES__': window.MAX_CROP_TYPES.toString(),
        '__CURRENT_TYPES__': Array.from(existingCropTypes).join('、')
      },
      `Maximum ${window.MAX_CROP_TYPES} crop types allowed.\nCurrent: ${Array.from(existingCropTypes).join(', ')}`
    );
    console.warn('⚠️ [CROP LIMIT] 作物種類が上限に達しています');
    alert(errorMessage);
    return;
  }
  
  // リクエスト中フラグを設定
  window.isAddingCrop = true;
  console.log('🔒 [LOCK] リクエスト中フラグを設定');

  // ローディング表示
  showLoadingOverlay();

  // data属性からURLを取得
  const ganttContainer = document.getElementById('gantt-chart-container');
  const baseUrl = ganttContainer?.dataset.addCropUrl;
  
  if (!baseUrl) {
    console.error('❌ data-add-crop-url属性が設定されていません');
    alert('APIエンドポイントが設定されていません。ページを再読み込みしてください。');
    return;
  }
  
  const url = baseUrl;

  const displayStartDateValue = ganttState.displayStartDate || ganttState.planStartDate;
  const displayEndDateValue = ganttState.displayEndDate || ganttState.planEndDate;
  const displayStartDateStr = formatAsIsoDate(displayStartDateValue);
  const displayEndDateStr = formatAsIsoDate(displayEndDateValue);

  const requestData = {
    crop_id: cropData.crop_id,
    field_id: dropInfo.field_id,
    start_date: dropInfo.start_date
  };

  if (displayStartDateStr) {
    requestData.display_start_date = displayStartDateStr;
  }

  if (displayEndDateStr) {
    requestData.display_end_date = displayEndDateStr;
  }
  
  const requestTimestamp = new Date().toISOString();
  console.log('📤 [REQUEST] 作物追加リクエスト送信:', requestTimestamp);
  console.log('📤 [REQUEST] URL:', url);
  console.log('📤 [REQUEST] データ:', requestData);
  console.log('📤 [REQUEST] field_id type:', typeof requestData.field_id, '値:', requestData.field_id);

  fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content || ''
    },
    body: JSON.stringify(requestData)
  })
  .then(response => {
    console.log('📥 [RESPONSE] レスポンス受信:', new Date().toISOString());
    console.log('📥 [RESPONSE] ステータス:', response.status);
    
    // レスポンスがJSONかどうかを確認
    const contentType = response.headers.get('content-type');
    if (!contentType || !contentType.includes('application/json')) {
      throw new Error(`Expected JSON response but got ${contentType || 'unknown content type'}`);
    }
    
    return response.json();
  })
  .then(data => {
    console.log('📥 [RESPONSE] データ:', data);
    if (data.success) {
      console.log('✅ [SUCCESS] 作物追加成功');
      // Action Cable経由で更新を待機
      // 成功時はAction Cableの更新後にフラグを解除（一時的にここで解除）
      window.isAddingCrop = false;
      console.log('🔓 [UNLOCK] リクエスト中フラグを解除（成功）');
    } else {
      console.error('❌ [ERROR] 作物の追加に失敗しました:', data.message);
      
      // 技術的な詳細があればコンソールに出力
      if (data.technical_details) {
        console.error('📋 Technical details:', data.technical_details);
      }
      
      hideLoadingOverlay();
      
      // フラグを解除
      window.isAddingCrop = false;
      console.log('🔓 [UNLOCK] リクエスト中フラグを解除（エラー）');
      
      // ユーザーフレンドリーなエラーメッセージを表示
      const failedMessage = data.message 
        ? getI18nTemplate('cropPaletteCropAddFailed', {'__MESSAGE__': data.message}, `Failed to add crop: ${data.message}`)
        : getI18nMessage('cropPaletteCropAddFailed', 'Failed to add crop');
      showErrorMessage(failedMessage);
    }
  })
  .catch(error => {
    console.error('❌ [ERROR] APIエラー:', error);
    hideLoadingOverlay();
    
    // フラグを解除
    window.isAddingCrop = false;
    console.log('🔓 [UNLOCK] リクエスト中フラグを解除（例外）');
    
    showErrorMessage(getI18nMessage('cropPaletteCommunicationError', 'Communication error occurred. Please try again.'));
  });
}

// ローディングオーバーレイを表示
function showLoadingOverlay(message = '最適化処理中...') {
  // 既存のオーバーレイを削除
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
  spinner.style.cssText = `
    background-color: white;
    padding: 30px 50px;
    border-radius: 10px;
    box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
    text-align: center;
    font-size: 16px;
    font-weight: 600;
    color: #374151;
  `;
  spinner.innerHTML = `
    <div style="margin-bottom: 15px;">
      <div style="
        border: 4px solid #f3f4f6;
        border-top: 4px solid #3b82f6;
        border-radius: 50%;
        width: 40px;
        height: 40px;
        animation: spin 1s linear infinite;
        margin: 0 auto;
      "></div>
    </div>
    <div>${message}</div>
  `;
  
  // アニメーションを追加（まだ存在しない場合）
  if (!document.getElementById('loading-spinner-style')) {
    const style = document.createElement('style');
    style.id = 'loading-spinner-style';
    style.textContent = `
      @keyframes spin {
        0% { transform: rotate(0deg); }
        100% { transform: rotate(360deg); }
      }
    `;
    document.head.appendChild(style);
  }
  
  overlay.appendChild(spinner);
  document.body.appendChild(overlay);
}

// ローディングオーバーレイを非表示
function hideLoadingOverlay() {
  const overlay = document.getElementById('reoptimization-overlay');
  if (overlay) {
    overlay.remove();
  }
}

// エラーメッセージを表示（見やすいモーダル）
function showErrorMessage(message) {
  // 既存のエラーメッセージを削除
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
    animation: fadeIn 0.2s ease-in;
  `;
  
  const modalContent = document.createElement('div');
  modalContent.style.cssText = `
    background-color: white;
    padding: 30px 40px;
    border-radius: 12px;
    box-shadow: 0 10px 25px rgba(0, 0, 0, 0.2);
    max-width: 500px;
    width: 90%;
    animation: slideIn 0.3s ease-out;
  `;
  
  modalContent.innerHTML = `
    <div style="display: flex; align-items: center; margin-bottom: 20px;">
      <div style="
        width: 48px;
        height: 48px;
        background-color: #FEE2E2;
        border-radius: 50%;
        display: flex;
        align-items: center;
        justify-content: center;
        margin-right: 15px;
      ">
        <svg style="width: 24px; height: 24px; color: #DC2626;" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
        </svg>
      </div>
      <h3 style="margin: 0; font-size: 18px; font-weight: 600; color: #1F2937;">作物の追加に失敗しました</h3>
    </div>
    <p style="margin: 0 0 25px 0; color: #4B5563; font-size: 15px; line-height: 1.6;">${message}</p>
    <button id="error-modal-close-btn" style="
      width: 100%;
      padding: 12px 24px;
      background-color: #3B82F6;
      color: white;
      border: none;
      border-radius: 8px;
      font-size: 15px;
      font-weight: 600;
      cursor: pointer;
      transition: background-color 0.2s;
    ">OK</button>
  `;
  
  // アニメーションを追加
  const style = document.createElement('style');
  style.textContent = `
    @keyframes fadeIn {
      from { opacity: 0; }
      to { opacity: 1; }
    }
    @keyframes slideIn {
      from { transform: translateY(-20px); opacity: 0; }
      to { transform: translateY(0); opacity: 1; }
    }
    #error-modal-close-btn:hover {
      background-color: #2563EB !important;
    }
  `;
  document.head.appendChild(style);
  
  modal.appendChild(modalContent);
  document.body.appendChild(modal);
  
  // 閉じるボタンのイベントリスナー
  const closeBtn = document.getElementById('error-modal-close-btn');
  closeBtn.addEventListener('click', () => {
    modal.style.animation = 'fadeOut 0.2s ease-out';
    setTimeout(() => modal.remove(), 200);
  });
  
  // モーダル外クリックで閉じる
  modal.addEventListener('click', (e) => {
    if (e.target === modal) {
      modal.style.animation = 'fadeOut 0.2s ease-out';
      setTimeout(() => modal.remove(), 200);
    }
  });
}

// グローバルに公開（他のスクリプトから使用される可能性があるため）
window.initCropPalette = initializeCropPalette;
window.toggleCropPalette = toggleCropPalette;


