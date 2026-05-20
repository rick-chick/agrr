// app/javascript/custom_gantt_chart.js
// カスタムSVGガントチャート（圃場ベース）- ドラッグ&ドロップ対応

// ファイル読み込み確認
if (typeof window.ClientLogger !== 'undefined') {
  window.ClientLogger.warn('📝 [Gantt Chart] custom_gantt_chart.js ファイル読み込み完了');
}

// 作物の色パレット管理（共通化）
// Turboページ遷移対応: すでに定義されている場合は再定義しない
if (typeof window.colorPalette === 'undefined') {
  window.colorPalette = [
    { fill: '#9ae6b4', stroke: '#48bb78' },   // 緑1
    { fill: '#fbd38d', stroke: '#f6ad55' },   // オレンジ
    { fill: '#90cdf4', stroke: '#4299e1' },   // 青
    { fill: '#c6f6d5', stroke: '#2f855a' },   // 緑2
    { fill: '#feebc8', stroke: '#dd6b20' },   // 淡いオレンジ
    { fill: '#feb2b2', stroke: '#fc8181' },   // 赤
    { fill: '#fef3c7', stroke: '#d69e2e' },   // 黄色
    { fill: '#e9d5ff', stroke: '#a78bfa' },   // 紫
    { fill: '#bfdbfe', stroke: '#60a5fa' },   // 水色
    { fill: '#fce7f3', stroke: '#f472b6' }    // ピンク
  ];
}

if (typeof window.cropColorMap === 'undefined') {
  window.cropColorMap = new Map();
}

function getCropColor(cropName) {
  const baseCropName = cropName.split('（')[0];
  
  if (!window.cropColorMap.has(baseCropName)) {
    const colorIndex = window.cropColorMap.size % window.colorPalette.length;
    window.cropColorMap.set(baseCropName, colorIndex);
  }
  
  const colorIndex = window.cropColorMap.get(baseCropName);
  return window.colorPalette[colorIndex].fill;
}

function getCropStrokeColor(cropName) {
  const baseCropName = cropName.split('（')[0];
  
  if (!window.cropColorMap.has(baseCropName)) {
    const colorIndex = window.cropColorMap.size % window.colorPalette.length;
    window.cropColorMap.set(baseCropName, colorIndex);
  }
  
  const colorIndex = window.cropColorMap.get(baseCropName);
  return window.colorPalette[colorIndex].stroke;
}

function getCropColors(cropName) {
  return {
    fill: getCropColor(cropName),
    stroke: getCropStrokeColor(cropName)
  };
}

// グローバルに公開
window.getCropColor = getCropColor;
window.getCropStrokeColor = getCropStrokeColor;
window.getCropColors = getCropColors;
window.cropColorPalette = window.colorPalette;

// グローバルステート管理
// Turboページ遷移対応: すでに定義されている場合は再利用
if (typeof window.ganttState === 'undefined') {
  window.ganttState = {
    cultivationData: [],
    fields: [], // 圃場情報（空の圃場も含む）
    fieldGroups: [],
    planStartDate: null,
    planEndDate: null,
    displayStartDate: null, // 表示範囲の開始日
    displayEndDate: null, // 表示範囲の終了日
    config: null,
    chartWidth: 0,
    chartHeight: 0,
    totalDays: 0,
    moves: [], // 移動履歴
    removedIds: [], // 削除されたID
    draggedBar: null,
    isDragging: false, // ドラッグ中かどうかを示すフラグ（グローバル管理）
    dragStartX: 0,
    dragStartY: 0,
    originalBarX: 0,
    originalFieldIndex: -1,
    dragStartDisplayStartDate: null, // ドラッグ開始時の表示範囲開始日（ドラッグ中のrenderGanttChart呼び出しから保護）
    dragStartDisplayEndDate: null, // ドラッグ開始時の表示範囲終了日（ドラッグ中のrenderGanttChart呼び出しから保護）
    cultivation_plan_id: null,
    cableSubscription: null, // Action Cableサブスクリプション
    // イベントハンドラーの参照を保存
    globalMouseMoveHandler: null,
    globalMouseUpHandler: null
  };
}

if (typeof window.ganttControlsInitialized === 'undefined') {
  window.ganttControlsInitialized = false;
}

if (typeof window.ganttFallbackResizeListener === 'undefined') {
  window.ganttFallbackResizeListener = false;
}

// ローディングインジケータの非表示タイマー
// Turboページ遷移などでスクリプトが複数回評価されても再定義エラーにならないよう、
// windowプロパティとして管理する
if (typeof window.ganttLoadingIndicatorHideTimer === 'undefined') {
  window.ganttLoadingIndicatorHideTimer = null;
}

function getGanttLoadingIndicator() {
  return document.getElementById('gantt-loading-indicator');
}

function setLoadingIndicatorVisible(visible) {
  const indicator = getGanttLoadingIndicator();
  if (!indicator) return;
  if (visible) {
    if (window.ganttLoadingIndicatorHideTimer) {
      clearTimeout(window.ganttLoadingIndicatorHideTimer);
      window.ganttLoadingIndicatorHideTimer = null;
    }
    indicator.classList.remove('is-hidden');
  } else {
    if (window.ganttLoadingIndicatorHideTimer) {
      clearTimeout(window.ganttLoadingIndicatorHideTimer);
    }
    window.ganttLoadingIndicatorHideTimer = window.setTimeout(() => {
      indicator.classList.add('is-hidden');
      window.ganttLoadingIndicatorHideTimer = null;
    }, 500);
  }
}

function getGanttFallbackElement() {
  return document.getElementById('gantt-chart-fallback');
}

function updateMobileFallback() {
  const fallback = getGanttFallbackElement();
  if (!fallback) return;

  const shouldShow = window.innerWidth <= 360;
  fallback.classList.toggle('is-visible', shouldShow);
  fallback.hidden = !shouldShow;
}

function handleGanttControlClick(event) {
  const action = event.currentTarget.dataset.ganttControl;
  if (!action) return;

  const container = document.getElementById('gantt-chart-container');
  const canvas = document.querySelector('.gantt-chart-canvas');

  switch (action) {
    case 'zoom-in': {
      if (container) {
        container.dataset.zoom = 'in';
      }
      if (canvas) {
        canvas.style.transformOrigin = 'top left';
        canvas.style.transform = 'scale(1.1)';
      }
      break;
    }
    case 'zoom-out': {
      if (container) {
        container.dataset.zoom = 'out';
      }
      if (canvas) {
        canvas.style.transformOrigin = 'top left';
        canvas.style.transform = 'scale(0.9)';
      }
      break;
    }
    case 'toggle-palette': {
      const paletteContainer = document.querySelector('.crop-palette-container');
      if (!paletteContainer) return;
      const isHidden = paletteContainer.classList.toggle('is-hidden-by-control');
      event.currentTarget.setAttribute('aria-pressed', isHidden ? 'true' : 'false');
      break;
    }
    default:
      break;
  }
}

function initGanttControls() {
  const controls = document.querySelector('[data-gantt-controls]');
  if (!controls) return;

  const buttons = controls.querySelectorAll('[data-gantt-control]');
  buttons.forEach((btn) => {
    if (btn.dataset.listenerAdded === 'true') return;
    btn.addEventListener('click', handleGanttControlClick);
    btn.dataset.listenerAdded = 'true';
  });

  window.ganttControlsInitialized = true;
}

// normalizeFieldId関数は共通ユーティリティ（gantt_data_utils.js）に移動


// 初期化関数（遅延実行でコンテナが確実に存在することを保証）
if (typeof window.MAX_RETRIES === 'undefined') {
  window.MAX_RETRIES = 50; // 最大5秒間待機 (100ms × 50)
}

// ガントチャートが存在するページかどうかを判定
function shouldHaveGanttChart() {
  const currentPath = window.location.pathname;
  const currentHash = window.location.hash;
  const currentHref = window.location.href;
  console.log('🔍 [Gantt Chart] ページ判定中:', currentPath, 'ハッシュ:', currentHash, 'フルURL:', currentHref);

  // ガントチャートが表示されるページのパターン
  const ganttPages = [
    '/plans/',  // 計画詳細ページ
    '/public_plans/',  // 公開計画詳細ページ
    '/results/'  // 結果ページ
  ];

  // パスまたはハッシュ部分をチェック（Angular SPAのハッシュルーティング対応）
  const hashPath = currentHash ? currentHash.replace('#', '') : '';
  // Angular SPAのルートパス（#/path）を適切に処理、クエリパラメータは除去
  const cleanHashPath = hashPath.split('?')[0];
  const pathToCheck = cleanHashPath ? cleanHashPath : currentPath;

  // より詳細なパターンマッチング
  const shouldHave = ganttPages.some(pattern => pathToCheck.includes(pattern)) ||
                    currentPath === '/public_plans/results' ||
                    pathToCheck.match(/\/public_plans\/\d+/) ||
                    pathToCheck.match(/\/plans\/\d+/) ||
                    currentHash.includes('/public-plans/results');

  console.log('🔍 [Gantt Chart] ページ判定結果:', shouldHave, 'チェック対象パス:', pathToCheck, 'パターン:', ganttPages);

  // 追加デバッグ: public_plansの場合の詳細ログ
  if (pathToCheck.includes('/public_plans/') || currentHash.includes('/public-plans/')) {
    console.log('📋 [Gantt Chart] Public plansページを検出:', pathToCheck, 'ハッシュ:', currentHash);
  }

  return shouldHave;
}

function initWhenReady() {
  if (typeof window.ganttRetryCount === 'undefined') {
    window.ganttRetryCount = 0;
  }

  console.log('🚀 [Gantt Chart] initWhenReady 開始', {
    retryCount: window.ganttRetryCount,
    currentPath: window.location.pathname,
    currentHref: window.location.href
  });

  // 対象ページでない場合はリトライを行わず即座にスキップする
  if (!shouldHaveGanttChart()) {
    console.log('ℹ️ [Gantt Chart] This page does not require a gantt chart - skipping initialization');
    if (typeof window.ClientLogger !== 'undefined') {
      window.ClientLogger.info('ℹ️ [Gantt Chart] This page does not require a gantt chart - skipping initialization');
    }
    window.ganttRetryCount = 0;
    return;
  }

  console.log('✅ [Gantt Chart] このページはガントチャートを表示すべきページです');

  const container = document.getElementById('gantt-chart-container');
  console.log('🔍 [Gantt Chart] コンテナ検索結果:', container ? '見つかった' : '見つからない');

  if (container) {
    console.log('🔍 [Gantt Chart] コンテナの詳細:', {
      id: container.id,
      className: container.className,
      dataset: container.dataset,
      innerHTML: container.innerHTML.substring(0, 200) + '...'
    });
  }
  
  if (container) {
    console.log('✅ [Gantt Chart] Container found, initializing...');
    if (typeof window.ClientLogger !== 'undefined') {
      window.ClientLogger.warn('✅ [Gantt Chart] Container found, initializing...');
    }
    window.ganttRetryCount = 0;
    initCustomGanttChart();
  } else if (window.ganttRetryCount < window.MAX_RETRIES) {
    window.ganttRetryCount++;
    console.log(`⏳ [Gantt Chart] Container not found yet, retrying... (${window.ganttRetryCount}/${window.MAX_RETRIES})`);
    if (typeof window.ClientLogger !== 'undefined') {
      window.ClientLogger.warn(`⏳ [Gantt Chart] Container not found yet, retrying... (${window.ganttRetryCount}/${window.MAX_RETRIES})`);
    }
    // リトライ間隔を徐々に長くする（100ms, 200ms, 300ms, ...）
    const retryDelay = Math.min(100 * window.ganttRetryCount, 500);
    setTimeout(initWhenReady, retryDelay);
  } else {
    // 最終リトライ後も見つからない場合
    if (shouldHaveGanttChart()) {
      console.warn('⚠️ [Gantt Chart] Container not found after all retries - this may indicate a problem');
      console.warn('⚠️ [Gantt Chart] Current page should have gantt chart but container is missing');
      console.warn('⚠️ [Gantt Chart] Page info:', {
        pathname: window.location.pathname,
        href: window.location.href,
        readyState: document.readyState
      });

      // デバッグ用のメッセージを表示（開発環境のみ）
      if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') {
        const debugDiv = document.createElement('div');
        debugDiv.style.cssText = `
          position: fixed;
          top: 10px;
          right: 10px;
          background: #fef3c7;
          border: 1px solid #f59e0b;
          padding: 10px;
          border-radius: 4px;
          z-index: 9999;
          font-size: 12px;
          max-width: 300px;
        `;
        debugDiv.innerHTML = `
          <strong>ガントチャートデバッグ:</strong><br>
          コンテナが見つかりません<br>
          ページ: ${window.location.pathname}<br>
          再試行回数: ${window.MAX_RETRIES}<br>
          <button onclick="this.parentElement.remove()">閉じる</button>
        `;
        document.body.appendChild(debugDiv);
      }
    } else {
      console.log('ℹ️ [Gantt Chart] This page does not require a gantt chart - skipping initialization');
      if (typeof window.ClientLogger !== 'undefined') {
        window.ClientLogger.info('ℹ️ [Gantt Chart] This page does not require a gantt chart - skipping initialization');
      }
    }
    window.ganttRetryCount = 0;
  }
}

// クリーンアップ関数
function cleanupGanttChart() {
  console.log('🧹 [Gantt Chart] クリーンアップ開始');
  if (typeof window.ClientLogger !== 'undefined') {
    window.ClientLogger.warn('🧹 [Gantt Chart] クリーンアップ開始');
  }
  
  // フラグをリセット
  window.ganttRetryCount = 0;
  
  // Action Cableサブスクリプションを切断
  if (window.ganttState && window.ganttState.cableSubscription) {
    window.ganttState.cableSubscription.unsubscribe();
    window.ganttState.cableSubscription = null;
    console.log('📡 [Gantt Chart] Action Cableサブスクリプションを切断しました');
  }
  
  // グローバルイベントハンドラーを削除
  if (window.ganttState && window.ganttState.globalMouseMoveHandler) {
    document.removeEventListener('mousemove', window.ganttState.globalMouseMoveHandler);
    window.ganttState.globalMouseMoveHandler = null;
  }
  if (window.ganttState && window.ganttState.globalMouseUpHandler) {
    document.removeEventListener('mouseup', window.ganttState.globalMouseUpHandler);
    window.ganttState.globalMouseUpHandler = null;
  }
  
  // ガントチャートコンテナをクリア
  const container = document.getElementById('gantt-chart-container');
  if (container) {
    container.innerHTML = '';
  }
  
  console.log('✅ [Gantt Chart] クリーンアップ完了');
  if (typeof window.ClientLogger !== 'undefined') {
    window.ClientLogger.warn('✅ [Gantt Chart] クリーンアップ完了');
  }
}

// Turbo対応: Frameレンダリング後に初期化（重複を避けるためturbo:frame-renderのみ使用）
(function() {
  console.log('🔧 [Gantt Chart] スクリプト読み込み完了', {
    currentPath: window.location.pathname,
    readyState: document.readyState,
    hasTurbo: typeof Turbo !== 'undefined',
    scriptLoadTime: new Date().toISOString()
  });

  function triggerInit() {
    console.log('🔄 [Gantt Chart] 初期化トリガー起動');
    // より長い遅延を設定してDOMが完全に準備できるようにする
    setTimeout(initWhenReady, 200);
  }

  // スクリプト実行の重複を防ぐためのフラグ
  if (window.ganttScriptInitialized) {
    console.log('ℹ️ [Gantt Chart] スクリプトが既に初期化されているためスキップ');
    return;
  }
  window.ganttScriptInitialized = true;

  // 初回読み込み時（DOMが既に読み込まれている場合）
  if (document.readyState !== 'loading') {
    console.log('🔄 [Gantt Chart] 既にDOM読み込み済み、即座に初期化');
    triggerInit();
    // モバイルフォールバック状態も評価
    updateMobileFallback();
  } else {
    // DOM読み込み待機
    document.addEventListener('DOMContentLoaded', () => {
      console.log('🔄 [Gantt Chart] DOMContentLoadedイベント検出、初期化開始');
      triggerInit();
      updateMobileFallback();
    });
  }

  if (typeof Turbo !== 'undefined') {
    console.log('🔧 [Gantt Chart] Turbo環境を検出、イベントリスナー登録中...');

    // Turbo Driveによるページ遷移時に初期化（全てのケースで確実に発火）
    document.addEventListener('turbo:load', () => {
      console.log('🔄 [Gantt Chart] turbo:load イベント検出', {
        currentPath: window.location.pathname,
        currentHref: window.location.href,
        timestamp: new Date().toISOString()
      });
      // 少し遅延させてDOMが完全に準備できるようにする
      setTimeout(() => {
        triggerInit();
        updateMobileFallback();
      }, 100);
    });

    // Turboでのフレームレンダリング時も初期化
    document.addEventListener('turbo:frame-load', () => {
      console.log('🔄 [Gantt Chart] turbo:frame-load イベント検出');
      setTimeout(() => {
        triggerInit();
        updateMobileFallback();
      }, 100);
    });

    // ページキャッシュ前にクリーンアップ
    document.addEventListener('turbo:before-cache', () => {
      console.log('🧹 [Gantt Chart] turbo:before-cache 検出 - クリーンアップを実行');
      cleanupGanttChart();
    });

    // Turboでのレンダリング完了時にも初期化を試行（確実性を高める）
    document.addEventListener('turbo:render', () => {
      console.log('🔄 [Gantt Chart] turbo:render イベント検出');
      setTimeout(() => {
        // 既に初期化されている場合はスキップ
        const container = document.getElementById('gantt-chart-container');
        if (container && !container.dataset.ganttInitialized) {
          console.log('🔄 [Gantt Chart] turbo:render で初期化を実行');
          triggerInit();
        }
      }, 50);
    });
  } else {
    console.log('⚠️ [Gantt Chart] Turboが利用できません。通常のページ遷移イベントを使用');

    // 通常のページ遷移時のイベント
    window.addEventListener('load', () => {
      console.log('🔄 [Gantt Chart] window load イベント検出');
      setTimeout(triggerInit, 100);
    });
  }

  // 確実性を高めるためのMutationObserver（DOM変更を監視）
  if (typeof MutationObserver !== 'undefined') {
    const observer = new MutationObserver((mutations) => {
      let shouldTriggerInit = false;
      mutations.forEach((mutation) => {
        // gantt-chart-containerが追加された場合
        mutation.addedNodes.forEach((node) => {
          if (node.id === 'gantt-chart-container' ||
              (node.querySelector && node.querySelector('#gantt-chart-container'))) {
            console.log('🔍 [Gantt Chart] MutationObserverでコンテナ検出');
            shouldTriggerInit = true;
          }
        });
      });

      if (shouldTriggerInit) {
        setTimeout(() => {
          const container = document.getElementById('gantt-chart-container');
          if (container && !container.dataset.ganttInitialized && shouldHaveGanttChart()) {
            console.log('🔄 [Gantt Chart] MutationObserverで初期化実行');
            triggerInit();
          }
        }, 100);
      }
    });

    // body要素の変更を監視
    observer.observe(document.body, {
      childList: true,
      subtree: true
    });

    console.log('👁️ [Gantt Chart] MutationObserverを設定しました');
  }
})();

function initCustomGanttChart() {
  console.log('🚀 [Gantt] initCustomGanttChart 開始', {
    currentPath: window.location.pathname,
    currentHref: window.location.href
  });
  if (typeof window.ClientLogger !== 'undefined') {
    window.ClientLogger.warn('🚀 [Gantt] initCustomGanttChart 開始');
  }

  const ganttContainer = document.getElementById('gantt-chart-container');
  setLoadingIndicatorVisible(true);
  if (!ganttContainer) {
    setLoadingIndicatorVisible(false);
    console.warn('⚠️ [Gantt] gantt-chart-container が見つかりません');
    if (typeof window.ClientLogger !== 'undefined') {
      window.ClientLogger.warn('⚠️ [Gantt] gantt-chart-container が見つかりません');
    }
    return;
  }

  console.log('✅ [Gantt] コンテナが見つかりました', {
    containerId: ganttContainer.id,
    dataset: ganttContainer.dataset,
    hasDataCultivations: !!ganttContainer.dataset.cultivations,
    hasDataFields: !!ganttContainer.dataset.fields
  });

  // 二重初期化防止（Turbo遷移や複数スクリプトからの呼び出し対策）
  if (ganttContainer.dataset.ganttInitialized === 'true') {
    console.log('ℹ️ [Gantt] 既に初期化済みのためスキップ');
    setLoadingIndicatorVisible(false);
    return;
  }

  if (!window.ganttControlsInitialized) {
    initGanttControls();
  }

  if (!window.ganttFallbackResizeListener) {
    window.addEventListener('resize', updateMobileFallback);
    window.ganttFallbackResizeListener = true;
  }
  updateMobileFallback();

  const ganttCanvas = document.querySelector('.gantt-chart-canvas');
  if (ganttCanvas) {
    ganttCanvas.style.transformOrigin = 'top left';
    ganttCanvas.style.transform = 'scale(1)';
  }
  ganttContainer.dataset.zoom = 'default';
  // 初期化済みフラグ
  ganttContainer.dataset.ganttInitialized = 'true';

  console.log('📊 [Gantt] データ属性を取得中...');
  // データ属性からJSONを取得
  const cultivationsRaw = JSON.parse(ganttContainer.dataset.cultivations || '[]');
  const fieldsDataRaw = JSON.parse(ganttContainer.dataset.fields || '[]');
  // ローカルタイムゾーンで日付を解釈（parseLocalDateを使用）
  window.ganttState.planStartDate = parseLocalDate(ganttContainer.dataset.planStartDate);
  window.ganttState.planEndDate = parseLocalDate(ganttContainer.dataset.planEndDate);

  console.log('📊 [Gantt] 生データ取得結果:', {
    cultivationsCount: cultivationsRaw.length,
    fieldsCount: fieldsDataRaw.length,
    planStartDate: ganttContainer.dataset.planStartDate,
    planEndDate: ganttContainer.dataset.planEndDate,
    parsedPlanStartDate: window.ganttState.planStartDate,
    parsedPlanEndDate: window.ganttState.planEndDate
  });

  // 計画期間の日付が有効であることを確認（異常系はエラーを上げる）
  if (!window.ganttState.planStartDate || !window.ganttState.planEndDate ||
      isNaN(window.ganttState.planStartDate.getTime()) || isNaN(window.ganttState.planEndDate.getTime())) {
    const errorMessage = `Invalid plan dates: planStartDate="${ganttContainer.dataset.planStartDate}", planEndDate="${ganttContainer.dataset.planEndDate}"`;
    console.error('❌ [Gantt] 無効な計画期間:', {
      planStartDate: ganttContainer.dataset.planStartDate,
      planEndDate: ganttContainer.dataset.planEndDate,
      parsedStart: window.ganttState.planStartDate,
      parsedEnd: window.ganttState.planEndDate
    });
    throw new Error(errorMessage);
  }
  
  // 表示範囲の初期値は計画期間全体
  window.ganttState.displayStartDate = window.ganttState.planStartDate;
  window.ganttState.displayEndDate = window.ganttState.planEndDate;
  window.ganttState.cultivation_plan_id = ganttContainer.dataset.cultivationPlanId;
  window.ganttState.plan_type = ganttContainer.dataset.planType || 'public';
  
  console.log('📊 [Gantt] 生データ:', { 
    cultivations: cultivationsRaw, 
    fields: fieldsDataRaw,
    planStartDate: ganttContainer.dataset.planStartDate,
    planEndDate: ganttContainer.dataset.planEndDate
  });
  
  // 移動履歴と削除IDをリセット
  window.ganttState.moves = [];
  window.ganttState.removedIds = [];

  // Action Cableサブスクリプションを設定
  setupCableSubscription(ganttContainer);

  console.log('🔧 [Gantt] データ正規化開始...');
  console.log('🔧 [Gantt] window.normalizeCultivationsData 存在確認:', typeof window.normalizeCultivationsData);
  console.log('🔧 [Gantt] window.normalizeFieldsData 存在確認:', typeof window.normalizeFieldsData);
  
  // 共通ユーティリティを使用してデータを正規化
  try {
    window.ganttState.cultivationData = window.normalizeCultivationsData(cultivationsRaw);
    const normalizedFields = window.normalizeFieldsData(fieldsDataRaw);
    
    console.log('🔧 初期化時の圃場情報（正規化前）:', fieldsDataRaw);
    console.log('🔧 初期化時の圃場情報（正規化後）:', normalizedFields);
    console.log('🔧 初期化時の栽培データ（正規化後）:', window.ganttState.cultivationData);

    // 圃場情報をganttStateに保存（空の圃場も含む）
    window.ganttState.fields = normalizedFields;

    // 圃場ごとにグループ化（圃場情報も含める）
    window.ganttState.fieldGroups = groupByField(window.ganttState.cultivationData, normalizedFields);

    console.log('🔧 初期化時のグループ化結果:', window.ganttState.fieldGroups);

    // フィールドが空の場合はエラーメッセージを表示
    if (window.ganttState.fieldGroups.length === 0) {
      console.warn('⚠️ [Gantt] 圃場データが空です。計画の作成時に問題が発生した可能性があります。');
      renderEmptyFieldsMessage(ganttContainer);
      setLoadingIndicatorVisible(false);
      return;
    }

    // 表示範囲選択UIのイベントハンドラーを設定
    setupDisplayRangeControls(ganttContainer);

    // SVGガントチャートを描画
    console.log('🎨 [Gantt] チャート描画開始...');
    // 計画期間は引数として渡さない（関数内で表示範囲を使用するため）
    renderGanttChart(ganttContainer, window.ganttState.fieldGroups);
    console.log('✅ [Gantt] チャート描画完了');
    
    // 初期化フラグをリセット
    window.ganttRetryCount = 0;
    console.log('✅ [Gantt Chart] 初期化完了、フラグをリセットしました');
  } catch (error) {
    console.error('❌ [Gantt] データ正規化エラー:', error);
    console.error('❌ [Gantt] スタックトレース:', error.stack);
    // エラー表示
    setLoadingIndicatorVisible(false);
    const errorDiv = document.createElement('div');
    errorDiv.style.cssText = `
      padding: 20px;
      background-color: #fee2e2;
      border: 1px solid #fecaca;
      border-radius: 8px;
      color: #dc2626;
      text-align: center;
      font-size: 14px;
    `;
    errorDiv.innerHTML = `
      <div style="margin-bottom: 10px;">📊 ガントチャートの読み込みに失敗しました</div>
      <div style="font-size: 12px; color: #7f1d1d;">
        エラー: ${error.message}<br>
        ページを再読み込みするか、管理者にお問い合わせください。
      </div>
    `;
    ganttContainer.innerHTML = '';
    ganttContainer.appendChild(errorDiv);

    // 初期化フラグ解除（次回再試行を可能に）
    delete ganttContainer.dataset.ganttInitialized;
    // エラー時も初期化フラグをリセット
    window.ganttRetryCount = 0;
    console.log('✅ [Gantt Chart] エラー後、フラグをリセットしました');
  }
}

// Action Cableサブスクリプションを設定
function setupCableSubscription(ganttContainer) {
  if (!window.ganttState.cultivation_plan_id) {
    console.warn('⚠️ cultivation_plan_idがないため、Action Cableサブスクリプションをスキップします');
    return;
  }

  // 既存のサブスクリプションがあれば解除
  if (window.ganttState.cableSubscription) {
    console.log('🔌 既存のAction Cableサブスクリプションを解除します');
    const channelName = ganttContainer.dataset.optimizationChannel || 'OptimizationChannel';
    if (window.CableSubscriptionManager) {
      window.CableSubscriptionManager.unsubscribe(window.ganttState.cultivation_plan_id, { channelName });
    }
    window.ganttState.cableSubscription = null;
  }

  // CableSubscriptionManagerが読み込まれていることを確認
  if (typeof window.CableSubscriptionManager === 'undefined') {
    console.error('❌ CableSubscriptionManager not loaded');
    throw new Error('CableSubscriptionManager is not loaded. Check asset loading order.');
  }

  console.log('📡 Action Cableサブスクリプションを設定中...');

  const channelName = ganttContainer.dataset.optimizationChannel || 'OptimizationChannel';
  window.ganttState.cableSubscription = window.CableSubscriptionManager.subscribeToOptimization(
    window.ganttState.cultivation_plan_id,
    {
      onConnected: () => {
        console.log(`✅ 最適化チャンネルに接続しました (${channelName})`);
      },
      onDisconnected: () => {
        console.log(`🔌 最適化チャンネルから切断されました (${channelName})`);
      },
      onReceived: (data) => {
        console.log('📬 最適化更新を受信:', data);
        console.log('📬 受信データタイプ:', data.type);
        console.log('📬 受信データ全体:', JSON.stringify(data, null, 2));
        handleOptimizationUpdate(data);
      }
    },
    { channelName }
  );
}

// 最適化更新を処理
function handleOptimizationUpdate(data) {
  console.log('🔄 最適化更新を処理中:', data);

  // 圃場追加の通知を処理
  if (data.type === 'field_added') {
    console.log('📊 圃場追加の通知を受信:', data.field);
    console.log('📊 受信データ詳細:', JSON.stringify(data, null, 2));
    
    // ローディングオーバーレイを非表示
    hideLoadingOverlay();
    
    // データを再取得してチャートを更新
    console.log('🔄 fetchAndUpdateChart()を呼び出します');
    fetchAndUpdateChart();
    return;
  }

  // 圃場削除の通知を処理
  if (data.type === 'field_removed') {
    console.log('📊 圃場削除の通知を受信:', data.field_id);
    console.log('📊 受信データ詳細:', JSON.stringify(data, null, 2));
    
    // ローディングオーバーレイを非表示
    hideLoadingOverlay();
    window.reoptimizationInProgress = false;
    
    // データを再取得してチャートを更新
    console.log('🔄 fetchAndUpdateChart()を呼び出します');
    fetchAndUpdateChart();
    return;
  }

  // ステータスが完了の場合
  if (data.status === 'completed' || data.status === 'adjusted' || (data.status === 'optimizing' && data.phase === 'completed')) {
    console.log('✅ 最適化が完了しました。データを更新します。');
    
    // ローディングオーバーレイを非表示
    hideLoadingOverlay();
    window.reoptimizationInProgress = false;

    // 最適化ページかどうかを判定
    const isOptimizingPage = document.querySelector('[data-optimizing-container]');
    
    if (isOptimizingPage) {
      // 最適化ページの場合はリダイレクトURLを取得して遷移
      const redirectUrl = isOptimizingPage.dataset.redirectUrl;
      if (redirectUrl) {
        console.log('🔄 最適化ページからリダイレクト:', redirectUrl);
        window.location.href = redirectUrl;
        return;
      }
    }

    // データを再取得してチャートを更新（ガントチャートが存在する場合のみ）
    fetchAndUpdateChart();
  } else if (data.status === 'failed') {
    console.error('❌ 最適化に失敗しました:', data.message);
    
    // ローディングオーバーレイを非表示
    hideLoadingOverlay();
    window.reoptimizationInProgress = false;

    // エラーメッセージを表示
    alert(data.message || getI18nMessage('jsGanttOptimizationFailed', 'Optimization failed'));
    
    // 変更を元に戻す
    revertChanges();
  } else if (data.progress !== undefined) {
    console.log(`📊 進捗: ${data.progress}%`);
    // 将来的に進捗バーを表示する場合はここで処理
  }
}

// データを再取得してチャートを更新
function fetchAndUpdateChart() {
  console.log('🔄 データを再取得中...');
  setLoadingIndicatorVisible(true);

  // data属性からURLを取得
  const ganttContainer = document.getElementById('gantt-chart-container');
  
  // ガントチャートコンテナが存在しない場合はスキップ（最適化ページなど）
  if (!ganttContainer) {
    console.log('ℹ️ ガントチャートコンテナが見つかりません。最適化ページの可能性があります。');
    return;
  }
  
  const url = ganttContainer.dataset.dataUrl;
  
  if (!url) {
    console.error('❌ data-data-url属性が設定されていません');
    const container = document.getElementById('gantt-container');
    alert(container?.dataset.apiEndpointMissing);
    setLoadingIndicatorVisible(false);
    return;
  }

  fetch(url, {
    method: 'GET',
    headers: {
      'Content-Type': 'application/json',
      'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content || ''
    }
  })
  .then(response => response.json())
  .then(data => {
    console.log('📊 データ取得成功:', data);
    // 新スキーマ対応: data.data に本体、totalsは data.totals
    const payload = (data && data.data) ? data.data : data;
    const totals = (data && data.totals) ? data.totals : {
      profit: data.total_profit,
      revenue: data.total_revenue,
      cost: data.total_cost
    };

    console.log('📊 取得した圃場情報:', payload.fields);
    console.log('📊 取得した栽培データ:', payload.cultivations);

    if (data.success) {
      // ⭐ adjustの結果を反映: 開始日と終了日の両方が更新される
      // adjustにより、開始日も終了日も変わる可能性がある
      // （例: 休閑期間確保のため開始日がずれる、気象条件により栽培期間が変わる）
      window.ganttState.cultivationData = payload.cultivations || [];
      
      // デバッグ: adjustの結果で更新された日付をログ出力
      if (payload.cultivations && payload.cultivations.length > 0) {
        console.log('🔄 adjust結果で更新された栽培データ:');
        payload.cultivations.forEach(c => {
          console.log(`  [${c.id}] ${c.crop_name}: ${c.start_date} 〜 ${c.completion_date}`);
        });
      }
      
      // 移動履歴と削除IDをリセット
      window.ganttState.moves = [];
      window.ganttState.removedIds = [];

      // 栽培データのfield_idも正規化
      // 共通ユーティリティを使用してデータを正規化
      window.ganttState.cultivationData = window.normalizeCultivationsData(window.ganttState.cultivationData);
      const normalizedFields = window.normalizeFieldsData(payload.fields || []);
      
      console.log('📊 正規化後の圃場情報:', normalizedFields);

      // 圃場情報をganttStateに保存（空の圃場も含む）
      window.ganttState.fields = normalizedFields;

      // 圃場ごとにグループ化（圃場情報も含める）
      window.ganttState.fieldGroups = groupByField(window.ganttState.cultivationData, normalizedFields);
      
      console.log('📊 グループ化結果:', window.ganttState.fieldGroups);

      // チャートを再描画（開始日と終了日の両方が正しく反映される）
      const ganttContainer = document.getElementById('gantt-chart-container');
      if (ganttContainer) {
        // 計画期間は引数として渡さない（関数内で表示範囲を使用するため）
        renderGanttChart(ganttContainer, window.ganttState.fieldGroups);
      }

      console.log('✅ チャートを更新しました（開始日・終了日の両方を反映）');
      
      // ローディングオーバーレイを非表示
      hideLoadingOverlay();
      
      // 圃場削除処理完了時はフラグをリセット
      window.reoptimizationInProgress = false;
      
      // カスタムイベントを発火（再描画完了を通知）
      const ganttReadyEvent = new CustomEvent('ganttChartReady', {
        detail: { ganttState: ganttState }
      });
      document.dispatchEvent(ganttReadyEvent);
      console.log('📡 ganttChartReady イベントを発火しました（再描画後）');
    } else {
      console.error('❌ データ取得に失敗しました');
      alert(getI18nMessage('jsGanttUpdateFailed', 'Failed to update data. Please reload the page manually.'));
      hideLoadingOverlay();
      setLoadingIndicatorVisible(false);
      window.reoptimizationInProgress = false;
    }
  })
  .catch(error => {
    console.error('❌ データ取得エラー:', error);
    alert(getI18nMessage('jsGanttFetchError', 'Error occurred while fetching data. Please reload the page manually.'));
    hideLoadingOverlay();
    setLoadingIndicatorVisible(false);
    window.reoptimizationInProgress = false;
  });
}

// 圃場ごとにグループ化（field_idベースでグループ化）
function groupByField(cultivations, fields = []) {
  const groups = {};
  
  // まず全ての圃場をグループに追加（空の圃場も含める）
  fields.forEach(field => {
    // field_idを"field_123"形式に統一
    const fieldId = window.normalizeFieldId(field.field_id || field.id);
    
    // field_idをキーとして使用（圃場名ではなく）
    groups[fieldId] = {
      fieldName: field.name,
      fieldId: fieldId,
      cultivations: []
    };
  });
  
  // 栽培スケジュールを圃場ごとに振り分け（field_idベース）
  cultivations.forEach(cultivation => {
    const fieldId = cultivation.field_id;
    
    if (!fieldId) {
      console.error('❌ cultivation.field_idが未定義です:', cultivation);
      throw new Error('cultivation.field_id is required');
    }
    
    // field_idでグループを検索
    if (!groups[fieldId]) {
      console.error('❌ field_idに対応する圃場が見つかりません:', fieldId);
      throw new Error(`Field not found for field_id=${fieldId}`);
    }
    groups[fieldId].cultivations.push(cultivation);
  });
  
  // 栽培を開始日順にソート
  Object.values(groups).forEach(group => {
    group.cultivations.sort((a, b) => {
      const dateA = parseLocalDate(a.start_date);
      const dateB = parseLocalDate(b.start_date);
      if (!dateA || !dateB) return 0;
      return dateA - dateB;
    });
  });
  
  return Object.values(groups);
}

// SVGガントチャートを描画
// 計画期間は引数として受け取らない（表示範囲を使用するため）
function renderGanttChart(container, fieldGroups) {
  const config = {
    margin: { top: 60, right: 20, bottom: 12, left: 80 },
    rowHeight: 68,
    barHeight: 48,
    barPadding: 8
  };

  const addFieldSpacer = fieldGroups.length > 0 ? config.barPadding + 40 : 0;
  config.height = config.margin.top + (fieldGroups.length * config.rowHeight) + addFieldSpacer + config.margin.bottom;

  // 表示範囲が設定されている場合はそれを使用、なければ計画期間全体を使用（フォールバック）
  let startDate, endDate;
  if (window.ganttState.displayStartDate && window.ganttState.displayEndDate) {
    startDate = window.ganttState.displayStartDate instanceof Date 
      ? new Date(window.ganttState.displayStartDate.getTime()) 
      : new Date(window.ganttState.displayStartDate);
    endDate = window.ganttState.displayEndDate instanceof Date 
      ? new Date(window.ganttState.displayEndDate.getTime()) 
      : new Date(window.ganttState.displayEndDate);
  } else {
    // フォールバック: 計画期間を使用
    const planStartDate = window.ganttState.planStartDate;
    const planEndDate = window.ganttState.planEndDate;
    startDate = planStartDate instanceof Date ? new Date(planStartDate.getTime()) : new Date(planStartDate);
    endDate = planEndDate instanceof Date ? new Date(planEndDate.getTime()) : new Date(planEndDate);
  }
  
  // 無効な日付の場合はエラーを発生
  if (isNaN(startDate.getTime()) || isNaN(endDate.getTime())) {
    console.error('❌ Invalid dates in renderGanttChart:', { 
      displayStartDate: window.ganttState.displayStartDate,
      displayEndDate: window.ganttState.displayEndDate,
      planStartDate: window.ganttState.planStartDate,
      planEndDate: window.ganttState.planEndDate
    });
    setLoadingIndicatorVisible(false);
    throw new Error('Invalid display range dates');
  }

  const totalDays = Math.max(daysBetween(startDate, endDate), 1);

  const parentWidth = container.parentElement?.getBoundingClientRect()?.width || 0;
  const containerWidth = container.getBoundingClientRect()?.width || 0;
  const fallbackWidth = 720;
  const availableWidth = Math.max(parentWidth, containerWidth, fallbackWidth);
  config.width = availableWidth;

  const chartWidth = config.width - config.margin.left - config.margin.right;
  const chartHeight = config.height - config.margin.top - config.margin.bottom;
  
  // chartWidthがNaNの場合はデフォルト値を設定
  if (isNaN(chartWidth) || chartWidth <= 0) {
    console.warn('Invalid chartWidth:', chartWidth);
    config.width = 1200;
    const fallbackChartWidth = config.width - config.margin.left - config.margin.right;
    console.log('Using fallback chartWidth:', fallbackChartWidth);
  }
  
  container.style.removeProperty("minWidth");
  container.style.removeProperty("width");
  container.style.maxWidth = "100%";
  container.style.width = "100%";
  const canvasWrapper = container.parentElement;
  if (canvasWrapper && canvasWrapper.classList.contains('gantt-chart-canvas')) {
    canvasWrapper.style.width = "100%";
    // スクロールエリアがコンテンツ幅（SVG幅）に追随するよう最小幅を確保
    canvasWrapper.style.minWidth = `${config.width}px`;
  }

  // グローバルステートに保存
  window.ganttState.config = config;
  window.ganttState.chartWidth = chartWidth;
  window.ganttState.chartHeight = chartHeight;
  window.ganttState.totalDays = totalDays;

  // SVG要素を作成
  const svg = createSVGElement('svg', {
    width: config.width,
    height: config.height,
    class: 'custom-gantt-chart',
    viewBox: `0 0 ${config.width} ${config.height}`,
    preserveAspectRatio: 'xMinYMin meet',
    style: 'pointer-events: auto;'
  });

  // グラデーション定義を追加
  const defs = createSVGElement('defs');
  
  // 背景グラデーション
  const bgGradient = createSVGElement('linearGradient', {
    id: 'bgGradient',
    x1: '0%',
    y1: '0%',
    x2: '0%',
    y2: '100%'
  });
  bgGradient.innerHTML = `
    <stop offset="0%" style="stop-color:#ffffff;stop-opacity:1" />
    <stop offset="100%" style="stop-color:#f9fafb;stop-opacity:1" />
  `;
  defs.appendChild(bgGradient);
  
  svg.appendChild(defs);

  // 背景（ドラッグ&ドロップを受け取る）
  svg.appendChild(createSVGElement('rect', {
    width: config.width,
    height: config.height,
    fill: 'url(#bgGradient)',
    style: 'pointer-events: all;',
    class: 'gantt-background'
  }));

  // タイムラインヘッダーを描画
  renderTimelineHeader(svg, config, startDate, endDate, totalDays, chartWidth);

  // 各圃場の行を描画
  fieldGroups.forEach((group, index) => {
    const y = config.margin.top + (index * config.rowHeight);
    renderFieldRow(svg, config, group, index, y, startDate, totalDays, chartWidth);
  });
  
  // 圃場追加ボタンを描画（最後の行の下）
  const addFieldBtnY = config.margin.top + (fieldGroups.length * config.rowHeight) + config.barPadding;
  const addFieldBtn = createSVGElement('g', {
    class: 'add-field-btn',
    style: 'cursor: pointer;'
  });
  
  // ボタン背景（より大きく、目立つように）
  const addFieldBtnRect = createSVGElement('rect', {
    x: 10,
    y: addFieldBtnY,
    width: 100,
    height: 35,
    rx: 8,
    ry: 8,
    fill: '#10B981',
    opacity: '0.95',
    stroke: '#059669',
    'stroke-width': '2'
  });
  
  // アイコン（＋マーク）
  const addFieldBtnIcon = createSVGElement('text', {
    x: 25,
    y: addFieldBtnY + 24,
    'text-anchor': 'middle',
    'font-size': '18',
    'font-weight': 'bold',
    fill: '#FFFFFF',
    style: 'pointer-events: none;'
  }, '+');
  
  // テキスト（i18n）
  const addFieldBtnText = createSVGElement('text', {
    x: 60,
    y: addFieldBtnY + 23,
    'text-anchor': 'middle',
    'font-size': '13',
    'font-weight': '600',
    fill: '#FFFFFF',
    style: 'pointer-events: none;'
  }, getI18nMessage('jsGanttAddFieldButton', '+ Add Field'));
  
  addFieldBtn.appendChild(addFieldBtnRect);
  addFieldBtn.appendChild(addFieldBtnIcon);
  addFieldBtn.appendChild(addFieldBtnText);
  
  addFieldBtn.addEventListener('click', function(e) {
    e.preventDefault();
    e.stopPropagation();
    console.log('🖱️ 圃場追加ボタンがクリックされました');
    addField();
  });
  
  addFieldBtn.addEventListener('mouseenter', function() {
    addFieldBtnRect.setAttribute('opacity', '1');
    addFieldBtnRect.setAttribute('fill', '#059669');
  });
  
  addFieldBtn.addEventListener('mouseleave', function() {
    addFieldBtnRect.setAttribute('opacity', '0.95');
    addFieldBtnRect.setAttribute('fill', '#10B981');
  });
  
  svg.appendChild(addFieldBtn);
  
  console.log('✅ 圃場追加ボタンを描画しました (Y座標:', addFieldBtnY, ')');

  // コンテナをクリアしてSVGを追加
  container.innerHTML = '';
  container.appendChild(svg);
  
  // グローバルなマウスイベントリスナーを追加（常に最新の参照を使用）
  // startDateは表示範囲の開始日（表示範囲が設定されている場合）または計画期間の開始日
  // endDateも同様に表示範囲の終了日または計画期間の終了日
  setupGlobalDragHandlers(svg, config, startDate, endDate, totalDays, chartWidth);
  setLoadingIndicatorVisible(false);
  updateMobileFallback();
  
  // カスタムイベントを発火（ガントチャート初期化完了を通知）
  const ganttReadyEvent = new CustomEvent('ganttChartReady', {
    detail: { ganttState: ganttState }
  });
  document.dispatchEvent(ganttReadyEvent);
}

// グローバルなドラッグハンドラーを設定
function setupGlobalDragHandlers(svg, config, displayStartDate, displayEndDate, totalDays, chartWidth) {
  const dragThreshold = 5; // 5px以上移動したらドラッグとみなす
  
  // ⭐ 重要: ドラッグ中はハンドラを置き換えない（ドラッグ開始時の日付範囲を保護）
  // ドラッグ中にrenderGanttChartが呼ばれても、既存のハンドラを保持する
  if (window.ganttState.isDragging || window.ganttState.draggedBar) {
    console.log('⚠️ ドラッグ中のため、ハンドラの置き換えをスキップします');
    return;
  }
  
  // 古いイベントハンドラーを削除
  if (window.ganttState.globalMouseMoveHandler) {
    document.removeEventListener('mousemove', window.ganttState.globalMouseMoveHandler);
  }
  if (window.ganttState.globalMouseUpHandler) {
    document.removeEventListener('mouseup', window.ganttState.globalMouseUpHandler);
  }
  
  // SVGのドラッグ&ドロップイベントは crop_palette_drag.js で処理されるため、
  // ここでは既存の栽培バーのドラッグのみ処理する
  
  // ハイライト矩形を最初から作成（再利用のため）
  let highlightRect = createSVGElement('rect', {
    class: 'field-row-highlight',
    fill: '#FFEB3B',
    opacity: '0',
    'pointer-events': 'none',
    x: 0,
    width: config.width
  });
  svg.insertBefore(highlightRect, svg.firstChild);
  
  let lastTargetFieldIndex = -1;
  
  // 要素の参照をキャッシュ
  let cachedBarBg = null;
  let cachedLabel = null;
  let cachedDeleteBtn = null;
  let cachedDeleteBtnText = null;
  let barWidth = 0;
  let barHeight = 0;
  
  // SVGの座標変換用（グローバルハンドラーから参照）
  let svgElement = svg; // SVG要素を保存
  let initialMouseSvgOffset = { x: 0, y: 0 }; // ドラッグ開始時のマウスと要素のオフセット（SVG座標系）
  
  // スクリーン座標をSVG座標に変換するヘルパー関数
  function screenToSVGCoords(svgElem, screenX, screenY) {
    if (!svgElem) {
      console.warn('SVG element is null, returning screen coordinates');
      return { x: screenX, y: screenY };
    }
    const pt = svgElem.createSVGPoint();
    pt.x = screenX;
    pt.y = screenY;
    const ctm = svgElem.getScreenCTM();
    if (ctm) {
      return pt.matrixTransform(ctm.inverse());
    }
    return { x: screenX, y: screenY };
  }
  
  // マウス移動（ドラッグ中）
  window.ganttState.globalMouseMoveHandler = function(e) {
    if (!window.ganttState.draggedBar) return;
    
    const mouseDeltaX = e.clientX - window.ganttState.dragStartX;
    const mouseDeltaY = e.clientY - window.ganttState.dragStartY;
    
    // ドラッグ開始判定（まだ開始していない場合）
    if (!window.ganttState.isDragging) {
      const distance = Math.sqrt(mouseDeltaX * mouseDeltaX + mouseDeltaY * mouseDeltaY);
      if (distance > dragThreshold) {
        // ドラッグ開始
        window.ganttState.isDragging = true;
        
        // トランジションを無効化（追随性を重視）
        window.ganttState.draggedBar.classList.add('dragging');
        
        // 要素の参照をキャッシュ（1回だけ）
        cachedBarBg = window.ganttState.draggedBar.querySelector('.bar-bg');
        cachedLabel = window.ganttState.draggedBar.querySelector('.bar-label');
        cachedDeleteBtn = window.ganttState.draggedBar.querySelector('.delete-btn circle');
        cachedDeleteBtnText = window.ganttState.draggedBar.querySelector('.delete-btn text');
        
        if (cachedBarBg) {
          cachedBarBg.style.cursor = 'grabbing';
          cachedBarBg.setAttribute('opacity', '0.8');
          cachedBarBg.setAttribute('stroke-width', '4');
          cachedBarBg.setAttribute('stroke-dasharray', '5,5');
          
          // サイズも1回だけ取得
          barWidth = parseFloat(cachedBarBg.getAttribute('width'));
          barHeight = parseFloat(cachedBarBg.getAttribute('height'));
          
          // マウスダウン位置をSVG座標に変換
          const startSvgCoords = screenToSVGCoords(svgElement, window.ganttState.dragStartX, window.ganttState.dragStartY);
          // 要素の左上とマウス位置のオフセットを記録（SVG座標系で）
          initialMouseSvgOffset.x = startSvgCoords.x - window.ganttState.originalBarX;
          initialMouseSvgOffset.y = startSvgCoords.y - parseFloat(cachedBarBg.getAttribute('y'));
        }
      } else {
        // まだ閾値に達していない
        return;
      }
    }
    
    // 現在のマウス位置をSVG座標に変換
    const currentSvgCoords = screenToSVGCoords(svgElement, e.clientX, e.clientY);
    
    // マウスの下にバーの角（ドラッグ開始位置）が来るように位置を計算
    const newX = currentSvgCoords.x - initialMouseSvgOffset.x;
    const newY = currentSvgCoords.y - initialMouseSvgOffset.y;
    
    // Y方向の移動から移動先の圃場インデックスを計算
    const ROW_HEIGHT = config.rowHeight;
    const originalBarY = parseFloat(cachedBarBg.getAttribute('data-original-y'));
    const deltaY = newY - originalBarY;
    const fieldIndexChange = Math.round(deltaY / ROW_HEIGHT);
    const targetFieldIndex = Math.max(0, Math.min(
      window.ganttState.originalFieldIndex + fieldIndexChange,
      window.ganttState.fieldGroups.length - 1
    ));
    
    // ハイライトの更新（圃場が変わった場合のみ）
    if (targetFieldIndex !== lastTargetFieldIndex) {
      const HEADER_HEIGHT = config.margin.top;
      const highlightY = HEADER_HEIGHT + (targetFieldIndex * ROW_HEIGHT);
      
      // 圃場が変わる場合のみハイライト表示
      if (targetFieldIndex !== window.ganttState.originalFieldIndex) {
        // 位置とサイズを更新（再利用）
        highlightRect.setAttribute('y', highlightY);
        highlightRect.setAttribute('height', ROW_HEIGHT);
        highlightRect.setAttribute('opacity', '0.4');
      } else {
        // 元の圃場に戻った場合はハイライトを非表示
        highlightRect.setAttribute('opacity', '0');
      }
      
      lastTargetFieldIndex = targetFieldIndex;
    }
    
    // SVG属性を直接更新（transitionは無効化済みなので高速）
    if (cachedBarBg) {
      cachedBarBg.setAttribute('x', newX);
      cachedBarBg.setAttribute('y', newY);
      
      // ラベルと削除ボタンも更新
      if (cachedLabel) {
        cachedLabel.setAttribute('x', newX + (barWidth / 2));
        cachedLabel.setAttribute('y', newY + (barHeight / 2) + 5);
      }
      
      if (cachedDeleteBtn && cachedDeleteBtnText) {
        const btnX = newX + barWidth - 10;
        const btnY = newY + 10;
        cachedDeleteBtn.setAttribute('cx', btnX);
        cachedDeleteBtn.setAttribute('cy', btnY);
        cachedDeleteBtnText.setAttribute('x', btnX);
        cachedDeleteBtnText.setAttribute('y', btnY + 5);
      }
    }
  };
  
  // マウスアップ（ドラッグ終了）
  window.ganttState.globalMouseUpHandler = function(e) {
    if (!window.ganttState.draggedBar) return;
    
    // ハイライトを非表示（削除せずに再利用のため残す）
    highlightRect.setAttribute('opacity', '0');
    
    const cultivation_id = window.ganttState.draggedBar.getAttribute('data-id');
    const originalFieldName = window.ganttState.draggedBar.getAttribute('data-field');
    
    // 現在の位置から新しい日付を計算（SVG属性は既に更新済み）
    const ROW_HEIGHT = config.rowHeight;
    const MARGIN_LEFT = config.margin.left;
    
    let newX, newFieldIndex, newFieldName, daysFromStart, newStartDate;
    
    if (cachedBarBg) {
      // 現在のSVG座標から計算
      newX = parseFloat(cachedBarBg.getAttribute('x'));
      const currentY = parseFloat(cachedBarBg.getAttribute('y'));
      const originalBarY = parseFloat(cachedBarBg.getAttribute('data-original-y'));
      
      // 日付計算（ドラッグ開始時に保存された表示範囲を使用）
      // ⭐ 重要: ドラッグ中にrenderGanttChartが呼ばれてdisplayStartDate/displayEndDateが
      // 更新されても、ドラッグ開始時の日付範囲を使用することで正しい日付計算を保証する
      const svg = document.querySelector('svg.custom-gantt-chart');
      const chartWidth = svg ? parseFloat(svg.getAttribute('width')) - MARGIN_LEFT - config.margin.right : 1080;
      // ドラッグ開始時に保存された日付範囲を使用（なければ現在の表示範囲を使用）
      const effectiveDisplayStartDate = window.ganttState.dragStartDisplayStartDate || displayStartDate || window.ganttState.planStartDate;
      const effectiveDisplayEndDate = window.ganttState.dragStartDisplayEndDate || displayEndDate || window.ganttState.planEndDate;
      const totalDays = daysBetween(effectiveDisplayStartDate, effectiveDisplayEndDate);
      daysFromStart = Math.round((newX - MARGIN_LEFT) / chartWidth * totalDays);
      newStartDate = new Date(effectiveDisplayStartDate);
      newStartDate.setDate(newStartDate.getDate() + daysFromStart);
      
      // 圃場計算
      const deltaY = currentY - originalBarY;
      const fieldIndexChange = Math.round(deltaY / ROW_HEIGHT);
      newFieldIndex = Math.max(0, Math.min(
        window.ganttState.originalFieldIndex + fieldIndexChange,
        window.ganttState.fieldGroups.length - 1
      ));
      
      // 配列の範囲チェック
      if (newFieldIndex >= 0 && newFieldIndex < window.ganttState.fieldGroups.length) {
        newFieldName = window.ganttState.fieldGroups[newFieldIndex].fieldName;
      } else {
        newFieldName = originalFieldName; // フォールバック
        newFieldIndex = window.ganttState.originalFieldIndex;
      }
    } else {
      // フォールバック（通常は実行されない）
      newX = window.ganttState.originalBarX;
      newFieldIndex = window.ganttState.originalFieldIndex;
      newFieldName = originalFieldName;
      // ドラッグ開始時に保存された日付範囲を使用（なければ現在の表示範囲を使用）
      const effectiveDisplayStartDate = window.ganttState.dragStartDisplayStartDate || displayStartDate || window.ganttState.planStartDate;
      const effectiveDisplayEndDate = window.ganttState.dragStartDisplayEndDate || displayEndDate || window.ganttState.planEndDate;
      const totalDays = daysBetween(effectiveDisplayStartDate, effectiveDisplayEndDate);
      const svg = document.querySelector('svg.custom-gantt-chart');
      const chartWidth = svg ? parseFloat(svg.getAttribute('width')) - MARGIN_LEFT - config.margin.right : 1080;
      daysFromStart = Math.round((newX - MARGIN_LEFT) / chartWidth * totalDays);
      newStartDate = new Date(effectiveDisplayStartDate);
      newStartDate.setDate(newStartDate.getDate() + daysFromStart);
    }
    
    // ⭐ 重要: 実際にドラッグが行われた場合のみ処理
    // クリック操作（isDragging = false）では最適化を実行しない
    if (window.ganttState.isDragging) {
      // さらに、有意な移動があった場合のみ最適化を実行
      // - 圃場が変わった、または
      // - 2日以上の日付移動があった
      if (originalFieldName !== newFieldName || Math.abs(daysFromStart) > 2) {
        console.log('📍 ドラッグ完了（最適化実行）:', {
          cultivation_id,
          from_field: originalFieldName,
          to_field: newFieldName,
          new_start_date: formatLocalDate(newStartDate),
          daysFromStart: daysFromStart
        });
        
        // 移動履歴に追加（この中でexecuteReoptimization()が呼ばれる）
        recordMove(cultivation_id, newFieldName, newStartDate);
        
        // チャートを再描画（変更を反映）
        applyMovesLocally();
      } else {
        console.log('ℹ️ ドラッグされたが移動量が小さいため最適化スキップ');
      }
    } else {
      console.log('ℹ️ クリック操作のため最適化スキップ');
    }
    
    // ドラッグ終了時のビジュアルリセット
    if (window.ganttState.draggedBar) {
      // トランジションを再有効化（draggingクラスを削除）
      window.ganttState.draggedBar.classList.remove('dragging');
      
      // カーソルと視覚効果をリセット
      if (cachedBarBg) {
        cachedBarBg.style.cursor = 'grab';
        cachedBarBg.setAttribute('opacity', '0.95');
        cachedBarBg.setAttribute('stroke-width', '2.5');
        cachedBarBg.removeAttribute('stroke-dasharray');
      }
    }
    
    // キャッシュをクリア
    cachedBarBg = null;
    cachedLabel = null;
    cachedDeleteBtn = null;
    cachedDeleteBtnText = null;
    lastTargetFieldIndex = -1;
    
    // ドラッグ開始時に保存した日付範囲をクリア
    window.ganttState.dragStartDisplayStartDate = null;
    window.ganttState.dragStartDisplayEndDate = null;
    
    window.ganttState.draggedBar = null;
    window.ganttState.isDragging = false;  // グローバルなドラッグフラグもリセット
  };
  
  // イベントリスナーを登録
  document.addEventListener('mousemove', window.ganttState.globalMouseMoveHandler);
  document.addEventListener('mouseup', window.ganttState.globalMouseUpHandler);
}

// 移動を記録（field_idベースで処理）
function recordMove(allocation_id, to_field_name, to_start_date) {
  // 既存の移動を削除（同じIDの場合）
  window.ganttState.moves = window.ganttState.moves.filter(m => m.allocation_id !== allocation_id);
  
  // 圃場IDを抽出（field_idベースで検索）
  const fieldGroup = window.ganttState.fieldGroups.find(g => g.fieldName === to_field_name);
  
  // 圃場IDを正しく取得
  let field_id;
  if (fieldGroup?.fieldId) {
    field_id = fieldGroup.fieldId;
  } else {
    console.error('❌ 圃場IDが取得できませんでした');
    console.error('🔍 fieldGroup:', fieldGroup);
    console.error('🔍 to_field_name:', to_field_name);
    console.error('🔍 全圃場グループ:', window.ganttState.fieldGroups);
    alert(getI18nMessage('jsGanttFieldInfoError', 'Error: Could not retrieve field information.\nPlease check console logs.'));
    return;
  }
  
  // field_idを"field_123"形式に統一してからmovesに追加
  const normalizedFieldId = window.normalizeFieldId(field_id);
  
  window.ganttState.moves.push({
    allocation_id: allocation_id,
    action: 'move',
    to_field_id: normalizedFieldId,
    to_start_date: formatLocalDate(to_start_date)
  });
  
  // 自動で再最適化を実行
  executeReoptimization();
}

// 削除を実行
function removeCultivation(cultivation_id) {
  console.log('🗑️ 削除:', cultivation_id);
  
  // 削除IDを記録
  window.ganttState.removedIds.push(cultivation_id);
  
  // 移動履歴に削除を追加
  window.ganttState.moves.push({
    allocation_id: cultivation_id,
    action: 'remove'
  });
  
  // ローカルで削除を適用
  window.ganttState.cultivationData = window.ganttState.cultivationData.filter(c => c.id != cultivation_id);
  // 空の圃場も含めて再グループ化
  window.ganttState.fieldGroups = groupByField(window.ganttState.cultivationData, window.ganttState.fields);
  
      // チャートを再描画
      const ganttContainer = document.getElementById('gantt-chart-container');
      if (ganttContainer) {
        // 計画期間は引数として渡さない（関数内で表示範囲を使用するため）
        renderGanttChart(ganttContainer, window.ganttState.fieldGroups);
      }
  
  // 自動で再最適化を実行
  executeReoptimization();
}

// ローカルで移動を適用（再描画用）
// ⭐ 注意: これは楽観的更新（optimistic update）です
// adjustの結果が返ってくると、開始日・終了日の両方が変わる可能性があります
function applyMovesLocally() {
  // 移動を適用
  window.ganttState.moves.filter(m => m.action === 'move').forEach(move => {
    const cultivation_id = parseInt(move.allocation_id);
    const cultivation = window.ganttState.cultivationData.find(c => c.id === cultivation_id);
    
    if (cultivation) {
      const oldStartDate = parseLocalDate(cultivation.start_date);
      const oldEndDate = parseLocalDate(cultivation.completion_date);
      
      // 無効な日付の場合はスキップ
      if (!oldStartDate || !oldEndDate) {
        console.warn('Invalid cultivation dates in applyMovesLocally:', { cultivation, oldStartDate, oldEndDate });
        return;
      }
      
      const duration = daysBetween(oldStartDate, oldEndDate);
      
      // 楽観的更新: ユーザーが指定した開始日と、元の期間を維持した終了日
      // ⭐ adjustの実際の結果では、開始日も終了日も変わる可能性がある
      const newStartDate = parseLocalDate(move.to_start_date);
      
      // 無効な新しい開始日の場合はスキップ
      if (!newStartDate) {
        console.warn('Invalid new start date in applyMovesLocally:', { move, newStartDate });
        return;
      }
      
      const newEndDate = new Date(newStartDate);
      newEndDate.setDate(newEndDate.getDate() + duration);
      
      // 開始日と終了日の両方を更新
      cultivation.start_date = formatLocalDate(newStartDate);
      cultivation.completion_date = formatLocalDate(newEndDate);
      
      console.log(`📝 楽観的更新 [${cultivation_id}] ${cultivation.crop_name}: ${cultivation.start_date} 〜 ${cultivation.completion_date}`);
      
      // 圃場名を更新（to_field_idから実際の圃場グループを検索）
      const normalizedToFieldId = window.normalizeFieldId(move.to_field_id);
      const targetFieldGroup = window.ganttState.fieldGroups.find(g => g.fieldId === normalizedToFieldId);
      if (targetFieldGroup) {
        cultivation.field_name = targetFieldGroup.fieldName;
        cultivation.field_id = targetFieldGroup.fieldId;
      } else {
        console.error('⚠️ 移動先の圃場が見つかりません:', normalizedToFieldId);
        console.error('🔍 利用可能な圃場:', window.ganttState.fieldGroups.map(g => g.fieldId));
      }
    }
  });
  
  // 削除を適用
  window.ganttState.cultivationData = window.ganttState.cultivationData.filter(c => 
    !window.ganttState.removedIds.includes(c.id)
  );
  
  // 圃場情報を抽出（現在のfieldGroupsから）
  const fieldsData = window.ganttState.fieldGroups.map(g => {
    // field_idを"field_123"形式に統一
    const normalizedFieldId = window.normalizeFieldId(g.fieldId);
    
    return {
      id: g.fieldId, // 元のIDをそのまま使用
      field_id: normalizedFieldId, // "field_123"形式
      name: g.fieldName,
      area: 0 // 面積は不明だが構造のために含める
    };
  });
  
  // 再グループ化
  window.ganttState.fieldGroups = groupByField(window.ganttState.cultivationData, fieldsData);
  
  // 再描画
  const ganttContainer = document.getElementById('gantt-chart-container');
  if (ganttContainer) {
    // 計画期間は引数として渡さない（関数内で表示範囲を使用するため）
    renderGanttChart(ganttContainer, window.ganttState.fieldGroups);
  }
}

// 手動の再最適化ボタンは不要（自動実行のため）

// 再最適化を実行（自動実行）
if (typeof window.reoptimizationInProgress === "undefined") { window.reoptimizationInProgress = false; }
if (typeof window.window.reoptimizationCallCount === "undefined") { window.window.reoptimizationCallCount = 0; }

function executeReoptimization() {
  window.reoptimizationCallCount++;
  const perfStart = performance.now();
  console.log(`🔄 自動再最適化を開始... (呼び出し回数: ${window.reoptimizationCallCount})`);
  console.log(`⏱️ [PERF] executeReoptimization() 開始時刻: ${perfStart.toFixed(2)}ms`);
  
  // 既に実行中の場合はスキップ
  if (window.reoptimizationInProgress) {
    console.warn('⚠️ 再最適化が既に実行中です。スキップします。');
    return;
  }
  
  window.reoptimizationInProgress = true;
  
  // 視覚的フィードバック: ローディングオーバーレイを表示
  showLoadingOverlay();
  
  // data属性からURLを取得
  const ganttContainer = document.getElementById('gantt-chart-container');
  const url = ganttContainer?.dataset.adjustUrl;
  
  if (!url) {
    console.error('❌ data-adjust-url属性が設定されていません');
    const container = document.getElementById('gantt-container');
    alert(container?.dataset.apiEndpointMissing);
    hideLoadingOverlay();
    window.reoptimizationInProgress = false;
    return;
  }
  
  console.log('📋 送信データ:', {
    cultivation_plan_id: window.ganttState.cultivation_plan_id,
    moves: window.ganttState.moves
  });
  
  const fetchStart = performance.now();
  console.log(`⏱️ [PERF] fetch()開始: ${(fetchStart - perfStart).toFixed(2)}ms経過`);
  
  fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content || ''
    },
    body: JSON.stringify({
      moves: window.ganttState.moves
    })
  })
  .then(response => {
    const responseReceivedTime = performance.now();
    console.log(`⏱️ [PERF] HTTPレスポンス受信: ${(responseReceivedTime - fetchStart).toFixed(2)}ms`);
    console.log('📡 HTTP Response:', response.status, response.statusText);
    return response.json().then(data => ({ status: response.status, data, responseReceivedTime }));
  })
  .then(({ status, data, responseReceivedTime }) => {
    const jsonParseTime = performance.now();
    console.log(`⏱️ [PERF] JSONパース完了: ${(jsonParseTime - responseReceivedTime).toFixed(2)}ms`);
    console.log('📊 API Response:', data);
    if (data.success) {
      console.log('✅ 再最適化リクエストが成功しました。Action Cable経由で更新を待機します。');
      const requestEnd = performance.now();
      console.log(`⏱️ [PERF] 合計処理時間: ${(requestEnd - perfStart).toFixed(2)}ms`);
      console.log(`⏱️ [PERF] - データ準備: ${(fetchStart - perfStart).toFixed(2)}ms`);
      console.log(`⏱️ [PERF] - API処理: ${(responseReceivedTime - fetchStart).toFixed(2)}ms`);
      console.log(`⏱️ [PERF] - JSONパース: ${(jsonParseTime - responseReceivedTime).toFixed(2)}ms`);
      console.log('📡 Action Cableからの更新を待機中...');
      // location.reload()は削除 - Action Cableからの通知を待つ
    } else {
      console.error('❌ 再最適化に失敗しました:', data.message);
      
      // エラーメッセージを解析して適切なメッセージを表示
      let userMessage = data.message || 'エラーが発生しました';
      
      if (userMessage.includes('Time overlap') || userMessage.includes('considering') || userMessage.includes('fallow period')) {
        userMessage = '移動先の日付では、他の栽培と重複します（休閑期間28日を考慮）。\n別の日付を選択してください。';
      } else if (userMessage.includes('Cannot complete growth')) {
        // 計画期間に関する制約を削除: 成長が完了できない場合は、単に成長が完了できないことを示す
        userMessage = '移動先の日付では、成長が完了しません。\nより早い日付を選択してください。';
      } else if (userMessage.includes('not found')) {
        userMessage = '指定された栽培または圃場が見つかりません。';
      }
      
      alert(userMessage);
      
      // 変更を元に戻す
      console.log('🔙 変更を元に戻します...');
      hideLoadingOverlay();
      window.reoptimizationInProgress = false;
      revertChanges();
    }
  })
  .catch(error => {
    console.error('❌ 再最適化エラー:', error);
    console.error('❌ エラー詳細:', error.stack);
    alert(getI18nMessage('jsGanttCommunicationError', 'Communication error occurred.\nPlease try again.'));
    
    // 変更を元に戻す
    console.log('🔙 変更を元に戻します...');
    hideLoadingOverlay();
    window.reoptimizationInProgress = false;
    revertChanges();
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
  
  // アニメーションを追加
  const style = document.createElement('style');
  style.textContent = `
    @keyframes spin {
      0% { transform: rotate(0deg); }
      100% { transform: rotate(360deg); }
    }
  `;
  document.head.appendChild(style);
  
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

// 変更を元に戻す（データ再取得）
function revertChanges() {
  // 移動履歴と削除IDをクリア
  window.ganttState.moves = [];
  window.ganttState.removedIds = [];
  
  // データを再取得して元の状態に戻す
  fetchAndUpdateChart();
}

// タイムラインヘッダーを描画
function renderTimelineHeader(svg, config, startDate, endDate, totalDays, chartWidth) {
  const headerGroup = createSVGElement('g', { class: 'timeline-header' });

  // 圃場列ヘッダー
  headerGroup.appendChild(createSVGElement('text', {
    x: 20,
    y: 30,
    class: 'header-label',
    'font-size': '14',
    'font-weight': 'bold',
    fill: '#374151'
  }, '圃場'));

  // 月ごとのヘッダーを描画
  const months = getMonthsInRange(startDate, endDate);
  let currentX = config.margin.left;

  months.forEach(month => {
    const monthDays = daysInMonth(month.year, month.month);
    const monthWidth = (monthDays / totalDays) * chartWidth;

    // 月ラベル（data属性からフォーマットを取得）
    const monthFormat = svg.dataset.monthFormat || '%{month}月';
    const monthLabel = monthFormat.replace('%{month}', month.month);
    headerGroup.appendChild(createSVGElement('text', {
      x: currentX + (monthWidth / 2),
      y: 30,
      class: 'month-label',
      'text-anchor': 'middle',
      'font-size': '13',
      'font-weight': '600',
      fill: '#1F2937'
    }, monthLabel));

    // 年ラベル（1月のみ）
    if (month.month === 1 || (month.month === months[0].month && month === months[0])) {
      headerGroup.appendChild(createSVGElement('text', {
        x: currentX + (monthWidth / 2),
        y: 15,
        class: 'year-label',
        'text-anchor': 'middle',
        'font-size': '12',
        'font-weight': 'bold',
        fill: '#6B7280'
      }, `${month.year}年`));
    }

    // 月の境界線（ドラッグ&ドロップを通過させる）
    headerGroup.appendChild(createSVGElement('line', {
      x1: currentX,
      y1: 40,
      x2: currentX,
      y2: config.height - config.margin.bottom,
      stroke: '#E5E7EB',
      'stroke-width': '1',
      style: 'pointer-events: none;'
    }));

    currentX += monthWidth;
  });

  svg.appendChild(headerGroup);
}

// 圃場行を描画
function renderFieldRow(svg, config, group, index, y, startDate, totalDays, chartWidth) {
  const rowGroup = createSVGElement('g', {
    class: 'field-row',
    'data-field': group.fieldName,
    'data-field-id': group.fieldId
  });


  // 圃場ラベル（左側）
  rowGroup.appendChild(createSVGElement('text', {
    x: 30,
    y: y + (config.rowHeight / 2) + 5,
    class: 'field-label',
    'text-anchor': 'middle',
    'font-size': '14',
    'font-weight': '600',
    fill: '#374151'
  }, group.fieldName));
  
  // 圃場削除ボタン（作物がない場合のみ表示）
  if (group.cultivations.length === 0 && window.ganttState.fieldGroups.length > 1) {
    const deleteFieldBtn = createSVGElement('g', {
      class: 'delete-field-btn',
      style: 'cursor: pointer;'
    });
    
    const deleteBtnCircle = createSVGElement('circle', {
      cx: 60,
      cy: y + (config.rowHeight / 2),
      r: 10,
      fill: '#EF4444',
      opacity: '0.8'
    });
    
    const deleteBtnX = createSVGElement('text', {
      x: 60,
      y: y + (config.rowHeight / 2) + 5,
      'text-anchor': 'middle',
      'font-size': '14',
      'font-weight': 'bold',
      fill: '#FFFFFF',
      style: 'pointer-events: none;'
    }, '×');
    
    deleteFieldBtn.appendChild(deleteBtnCircle);
    deleteFieldBtn.appendChild(deleteBtnX);
    
    deleteFieldBtn.addEventListener('click', function(e) {
      e.preventDefault();
      e.stopPropagation();
      
      const message = getI18nTemplate('jsGanttConfirmDeleteField', {field_name: group.fieldName}, `Delete ${group.fieldName}?\n(This field has no crops and can be deleted)`);
      if (confirm(message)) {
        removeField(group.fieldId);
      }
    });
    
    deleteFieldBtn.addEventListener('mouseenter', function() {
      deleteBtnCircle.setAttribute('opacity', '1');
    });
    
    deleteFieldBtn.addEventListener('mouseleave', function() {
      deleteBtnCircle.setAttribute('opacity', '0.8');
    });
    
    rowGroup.appendChild(deleteFieldBtn);
  }

  // 圃場列の右端線（ドラッグ&ドロップを通過させる）
  rowGroup.appendChild(createSVGElement('line', {
    x1: config.margin.left - 10,
    y1: y,
    x2: config.margin.left - 10,
    y2: y + config.rowHeight,
    stroke: '#D1D5DB',
    'stroke-width': '2',
    style: 'pointer-events: none;'
  }));

  // 各栽培のバーを描画（表示範囲内のもののみ）
  // startDateは表示範囲の開始日（表示範囲が設定されている場合）または計画期間の開始日
  group.cultivations.forEach((cultivation, cultIndex) => {
    if (shouldDisplayCultivation(cultivation)) {
      // startDateは表示範囲の開始日として渡す
      renderCultivationBar(rowGroup, config, cultivation, y, startDate, totalDays, chartWidth);
    }
  });

  svg.appendChild(rowGroup);
}

// 栽培バーを描画
// ⭐ ガントカードの位置と幅は、開始日と終了日の両方から計算される
function renderCultivationBar(parentGroup, config, cultivation, rowY, displayStartDate, totalDays, chartWidth) {
  // 開始日と終了日を取得（ローカルタイムゾーンで解釈）
  const startDate = parseLocalDate(cultivation.start_date);
  const endDate = parseLocalDate(cultivation.completion_date);
  
  // 無効な日付の場合はスキップ
  if (!startDate || !endDate || isNaN(startDate.getTime()) || isNaN(endDate.getTime())) {
    console.warn('Invalid cultivation dates:', { cultivation, startDate, endDate });
    return;
  }
  
  // 日数計算（符号を保持して計算）
  // 表示範囲の開始日より前に始まる作付の場合、負の値になる
  const daysFromStart = daysBetweenSigned(displayStartDate, startDate);
  const cultivationDays = daysBetween(startDate, endDate) + 1;
  
  if (cultivationDays <= 0) {
    console.warn('Invalid cultivation period calculation:', { 
      cultivation, 
      daysFromStart, 
      cultivationDays,
      displayStartDate,
      startDate,
      endDate
    });
    return;
  }
  
  // 表示範囲の終了日を取得（表示範囲が設定されている場合）
  const displayEndDate = window.ganttState?.displayEndDate 
    ? (window.ganttState.displayEndDate instanceof Date 
       ? new Date(window.ganttState.displayEndDate.getTime())
       : new Date(window.ganttState.displayEndDate))
    : null;
  
  // 表示範囲内の実際の開始日と終了日を計算
  let visibleStartDate = startDate;
  let visibleEndDate = endDate;
  
  // 表示範囲の開始日より前に始まる場合は、表示範囲の開始日から表示
  if (daysFromStart < 0) {
    visibleStartDate = new Date(displayStartDate);
  }
  
  // 表示範囲の終了日を超える場合は、表示範囲の終了日までに切り詰める
  if (displayEndDate && endDate > displayEndDate) {
    visibleEndDate = new Date(displayEndDate);
  }
  
  // 表示範囲内の実際の日数を計算
  const visibleDays = daysBetween(visibleStartDate, visibleEndDate) + 1;
  
  if (visibleDays <= 0) {
    // 表示範囲内に表示する部分がない場合はスキップ
    return;
  }
  
  // 日数ベースの座標計算
  // ⭐ barXは開始日から計算される（adjustで開始日が変わると位置も変わる）
  // ⭐ barWidthは開始日と終了日から計算される（adjustで期間が変わると幅も変わる）
  // 表示範囲の開始日より前に始まる作付の場合、barXは0から始まり、barWidthを調整
  
  let barX, barWidth;
  if (daysFromStart < 0) {
    // 表示範囲の開始日より前に始まる作付の場合
    // バーは表示範囲の左端から始まり、表示範囲内の部分のみ表示
    barX = config.margin.left;
    barWidth = Math.max(0, (visibleDays / totalDays) * chartWidth);
  } else {
    // 表示範囲の開始日以降に始まる作付の場合
    const visibleDaysFromStart = daysBetweenSigned(displayStartDate, visibleStartDate);
    barX = config.margin.left + (visibleDaysFromStart / totalDays) * chartWidth;
    barWidth = (visibleDays / totalDays) * chartWidth;
  }
  const barY = rowY + config.barPadding;
  
  // NaNチェック
  if (isNaN(barX) || isNaN(barWidth) || isNaN(barY)) {
    console.warn('Invalid bar coordinates:', { 
      barX, 
      barWidth, 
      barY, 
      daysFromStart, 
      cultivationDays, 
      totalDays, 
      chartWidth 
    });
    return;
  }
  
  // バーグループ
  const barGroup = createSVGElement('g', {
    class: 'cultivation-bar',
    'data-id': cultivation.id,
    'data-crop': cultivation.crop_name,
    'data-field': cultivation.field_name
  });

  // 移動可能かどうかを判定
  const movable = isMovable(cultivation);
  
  // 表示範囲外の作付は半透明で表示
  let barOpacity = '0.95';
  let barStyle = 'cursor: grab;';
  if (!movable) {
    barOpacity = '0.5';
    barStyle = 'cursor: not-allowed;';
  }
  
  // バーの背景
  const barBg = createSVGElement('rect', {
    x: barX,
    y: barY,
    width: barWidth,
    height: config.barHeight,
    rx: 6,
    ry: 6,
    fill: window.getCropColor(cultivation.crop_name),
    stroke: window.getCropStrokeColor(cultivation.crop_name),
    'stroke-width': '2.5',
    class: 'bar-bg',
    style: barStyle,
    opacity: barOpacity,
    'data-movable': movable ? 'true' : 'false'
  });

  // クリックイベントを追加（詳細パネル表示）
  barBg.addEventListener('click', function(e) {
    e.preventDefault();
    e.stopPropagation();
    console.log('🖱️ 栽培バーがクリックされました:', cultivation);
    
    // 詳細パネルを表示
    if (typeof window.showDetailPanel === 'function') {
      window.showDetailPanel(cultivation.id, cultivation.field_name, cultivation.crop_name);
    }
  });

  // ホバー効果を追加
  barBg.addEventListener('mouseenter', function() {
    this.setAttribute('opacity', '1');
    this.setAttribute('stroke-width', '3.5');
    // movableフラグに基づいてカーソルを設定
    this.style.cursor = movable ? 'grab' : 'not-allowed';
  });
  
  barBg.addEventListener('mouseleave', function() {
    if (window.ganttState.draggedBar !== barGroup) {
      this.setAttribute('opacity', barOpacity);
      this.setAttribute('stroke-width', '2.5');
      // 元のカーソルを復元
      this.style.cursor = movable ? 'grab' : 'not-allowed';
    }
  });
  
  barGroup.appendChild(barBg);

  // ドラッグとクリックを区別するための変数
  // ローカルのisDraggingは削除し、window.ganttState.isDraggingを使用
  let dragThreshold = 5; // 5px以上移動したらドラッグとみなす
  let mouseDownTime = 0;
  let clickTimeout = null;

  // ドラッグ開始
  barBg.addEventListener('mousedown', function(e) {
    // 右クリックは除外
    if (e.button !== 0) return;
    
    // 移動不可の作付はドラッグをブロック
    if (!movable) {
      console.log('⚠️ 表示範囲外の作付は移動できません');
      return;
    }
    
    // 再最適化中は操作を受け付けない
    if (window.reoptimizationInProgress) {
      console.log('⚠️ 再最適化中のため操作をブロックしました');
      return;
    }
    
    // ドラッグの準備（まだドラッグは開始していない）
    window.ganttState.isDragging = false;
    window.ganttState.draggedBar = barGroup; // グローバルハンドラーが動作するように設定
    mouseDownTime = Date.now();
    window.ganttState.dragStartX = e.clientX;
    window.ganttState.dragStartY = e.clientY;
    window.ganttState.originalBarX = parseFloat(barBg.getAttribute('x'));
    
    // ⭐ 重要: ドラッグ開始時の表示範囲を保存
    // これにより、ドラッグ中にrenderGanttChartが呼ばれてdisplayStartDate/displayEndDateが
    // 更新されても、ドラッグ開始時の日付範囲を使用して正しい日付計算ができる
    window.ganttState.dragStartDisplayStartDate = window.ganttState.displayStartDate 
      ? new Date(window.ganttState.displayStartDate.getTime())
      : (window.ganttState.planStartDate ? new Date(window.ganttState.planStartDate.getTime()) : null);
    window.ganttState.dragStartDisplayEndDate = window.ganttState.displayEndDate
      ? new Date(window.ganttState.displayEndDate.getTime())
      : (window.ganttState.planEndDate ? new Date(window.ganttState.planEndDate.getTime()) : null);
    
    // 元のY座標を保存（data-original-y属性として）
    const originalBarY = parseFloat(barBg.getAttribute('y'));
    barBg.setAttribute('data-original-y', originalBarY);
    
    // 現在のフィールドインデックスを保存
    const currentFieldName = cultivation.field_name;
    window.ganttState.originalFieldIndex = window.ganttState.fieldGroups.findIndex(g => g.fieldName === currentFieldName);
    
    // デフォルトのドラッグ動作を防止
    e.preventDefault();
  });

  // 注: ドラッグ判定はグローバルなmousemoveハンドラーで行うため、
  // バー固有のmousemoveハンドラーは不要

  // マウスアップ（クリック判定）
  // 注: グローバルハンドラーが先に実行されるため、クリック判定のみ行う
  barBg.addEventListener('mouseup', function(e) {
    if (mouseDownTime === 0) return;
    
    const clickDuration = Date.now() - mouseDownTime;
    
    // ドラッグされていない、かつ短時間のマウスダウン＝クリック
    if (!window.ganttState.isDragging && clickDuration < 300) {
      // 再最適化中は操作を受け付けない
      if (window.reoptimizationInProgress) {
        console.log('⚠️ 再最適化中のため操作をブロックしました');
        mouseDownTime = 0;
        return;
      }
      
      // クリック処理（気温チャートを表示）
      console.log('🖱️ クリック:', cultivation.crop_name);
      showClimateChart(cultivation.id);
    }
    
    mouseDownTime = 0;
  });

  // 右クリック（コンテキストメニュー）で削除
  barBg.addEventListener('contextmenu', function(e) {
    e.preventDefault();
    e.stopPropagation();
    
    // 再最適化中は操作を受け付けない
    if (window.reoptimizationInProgress) {
      console.log('⚠️ 再最適化中のため操作をブロックしました');
      return;
    }
    
    const message = getI18nTemplate('jsGanttConfirmDeleteCrop', {crop_name: cultivation.crop_name}, `Delete ${cultivation.crop_name}?`);
    if (confirm(message)) {
      removeCultivation(cultivation.id);
    }
  });

  // バーのラベル（作物名）- 常に表示
  const labelText = cultivation.crop_name;
  
  const label = createSVGElement('text', {
    x: barX + (barWidth / 2),
    y: barY + (config.barHeight / 2) + 5,
    class: 'bar-label',
    'text-anchor': 'middle',
    'font-size': '12',
    'font-weight': '600',
    fill: '#1F2937',
    style: 'pointer-events: none;'
  }, labelText);
  
  barGroup.appendChild(label);
  
  // 削除ボタン（小さいバツボタン）
  const deleteBtn = createSVGElement('g', {
    class: 'delete-btn',
    style: 'cursor: pointer;'
  });
  
  const deleteBtnCircle = createSVGElement('circle', {
    cx: barX + barWidth - 10,
    cy: barY + 10,
    r: 8,
    fill: '#EF4444',
    opacity: '0.9'
  });
  
  const deleteBtnX = createSVGElement('text', {
    x: barX + barWidth - 10,
    y: barY + 15,
    'text-anchor': 'middle',
    'font-size': '12',
    'font-weight': 'bold',
    fill: '#FFFFFF',
    style: 'pointer-events: none;'
  }, '×');
  
  deleteBtn.appendChild(deleteBtnCircle);
  deleteBtn.appendChild(deleteBtnX);
  
  deleteBtn.addEventListener('click', function(e) {
    e.preventDefault();
    e.stopPropagation();
    
    // 再最適化中は操作を受け付けない
    if (window.reoptimizationInProgress) {
      console.log('⚠️ 再最適化中のため操作をブロックしました');
      return;
    }
    
    const message = getI18nTemplate('jsGanttConfirmDeleteCrop', {crop_name: cultivation.crop_name}, `Delete ${cultivation.crop_name}?`);
    if (confirm(message)) {
      removeCultivation(cultivation.id);
    }
  });
  
  deleteBtn.addEventListener('mouseenter', function() {
    deleteBtnCircle.setAttribute('opacity', '1');
  });
  
  deleteBtn.addEventListener('mouseleave', function() {
    deleteBtnCircle.setAttribute('opacity', '0.9');
  });
  
  barGroup.appendChild(deleteBtn);

  parentGroup.appendChild(barGroup);
}

// 月の範囲を取得
function getMonthsInRange(startDate, endDate) {
  const months = [];
  const current = new Date(startDate);
  
  while (current <= endDate) {
    months.push({
      year: current.getFullYear(),
      month: current.getMonth() + 1
    });
    current.setMonth(current.getMonth() + 1);
  }
  
  return months;
}

// 月の日数を取得
function daysInMonth(year, month) {
  return new Date(year, month, 0).getDate();
}

// 2つの日付間の日数を計算（絶対値、符号なし）
function daysBetween(date1, date2) {
  // 日付をDateオブジェクトに変換（文字列の場合は変換）
  const d1 = typeof date1 === 'string' ? new Date(date1) : date1;
  const d2 = typeof date2 === 'string' ? new Date(date2) : date2;
  
  // 無効な日付の場合はエラーを発生（異常系はフォールバックではなくエラーを上げる）
  if (isNaN(d1.getTime()) || isNaN(d2.getTime())) {
    throw new Error(`Invalid date in daysBetween: date1=${date1}, date2=${date2}, d1=${d1}, d2=${d2}`);
  }
  
  const oneDay = 24 * 60 * 60 * 1000;
  const result = Math.round(Math.abs((d2 - d1) / oneDay));
  
  // 結果が0以下の場合は最小値を返す
  return Math.max(result, 1);
}

// 2つの日付間の日数を計算（符号付き、date2 - date1）
function daysBetweenSigned(date1, date2) {
  // 日付をDateオブジェクトに変換（文字列の場合は変換）
  const d1 = typeof date1 === 'string' ? new Date(date1) : date1;
  const d2 = typeof date2 === 'string' ? new Date(date2) : date2;
  
  // 無効な日付の場合はエラーを発生（異常系はフォールバックではなくエラーを上げる）
  if (isNaN(d1.getTime()) || isNaN(d2.getTime())) {
    throw new Error(`Invalid date in daysBetweenSigned: date1=${date1}, date2=${date2}, d1=${d1}, d2=${d2}`);
  }
  
  const oneDay = 24 * 60 * 60 * 1000;
  const result = Math.round((d2 - d1) / oneDay);
  
  return result;
}

// 日付フォーマット
function formatDate(date, format = 'full') {
  const month = date.getMonth() + 1;
  const day = date.getDate();
  
  if (format === 'short') {
    return `${month}/${day}`;
  }
  
  const year = date.getFullYear();
  return `${year}/${month}/${day}`;
}

// 作物の色パレット管理は crop_colors.js で共通化
// このファイルでは getCropColor / getCropStrokeColor を window オブジェクトから使用

// SVG要素を作成
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

// ポップアップを表示
function showCultivationPopup(cultivation, x, y) {
  console.log('🖱️ Cultivation clicked:', cultivation);
  
  // 既存のポップアップを削除
  const existingPopup = document.querySelector('.gantt-custom-popup');
  if (existingPopup) {
    existingPopup.remove();
  }

  // ポップアップHTML
  const popup = document.createElement('div');
  popup.className = 'gantt-custom-popup';
  popup.innerHTML = `
    <div class="popup-header">
      <strong>${cultivation.crop_name}</strong>
      <button class="popup-close" onclick="this.parentElement.parentElement.remove()">×</button>
    </div>
    <div class="popup-body">
      <div class="popup-item">
        <span class="popup-label">圃場:</span>
        <span class="popup-value">${cultivation.field_name}</span>
      </div>
      <div class="popup-item">
        <span class="popup-label">期間:</span>
        <span class="popup-value">${cultivation.start_date} 〜 ${cultivation.completion_date}</span>
      </div>
      <div class="popup-item">
        <span class="popup-label">栽培日数:</span>
        <span class="popup-value">${cultivation.cultivation_days}日</span>
      </div>
      <div class="popup-item">
        <span class="popup-label">面積:</span>
        <span class="popup-value">${cultivation.area}㎡</span>
      </div>
      <div class="popup-item">
        <span class="popup-label">推定コスト:</span>
        <span class="popup-value">¥${formatNumber(cultivation.estimated_cost)}</span>
      </div>
      ${cultivation.profit ? `
        <div class="popup-item">
          <span class="popup-label">利益:</span>
          <span class="popup-value profit">¥${formatNumber(cultivation.profit)}</span>
        </div>
      ` : ''}
    </div>
  `;

  // 位置を設定（画面内に収める）
  popup.style.position = 'fixed';
  popup.style.left = `${Math.min(x + 10, window.innerWidth - 300)}px`;
  popup.style.top = `${Math.min(y + 10, window.innerHeight - 400)}px`;

  document.body.appendChild(popup);

  // 外側クリックで閉じる
  setTimeout(() => {
    document.addEventListener('click', function closePopup(e) {
      if (!popup.contains(e.target)) {
        popup.remove();
        document.removeEventListener('click', closePopup);
      }
    });
  }, 100);
}

// 数値フォーマット
function formatNumber(num) {
  if (num === null || num === undefined) return '-';
  return Math.round(num).toLocaleString('ja-JP');
}

// 気温・GDDチャートを表示
function showClimateChart(cultivationId) {
  console.log('🌡️ Showing climate chart for cultivation:', cultivationId);
  
  // チャートコンテナを取得または作成
  let chartContainer = document.getElementById('climate-chart-display');
  
  if (!chartContainer) {
    // ガントチャートの直後に挿入
    const ganttContainer = document.getElementById('gantt-chart-container');
    if (!ganttContainer) return;
    
    chartContainer = document.createElement('div');
    chartContainer.id = 'climate-chart-display';
    chartContainer.className = 'climate-chart-display';
    
    // 広告の前に挿入（広告が存在する場合）
    const adSection = ganttContainer.nextElementSibling;
    if (adSection && adSection.classList.contains('ad-section')) {
      ganttContainer.parentNode.insertBefore(chartContainer, adSection);
    } else {
      ganttContainer.parentNode.insertBefore(chartContainer, ganttContainer.nextSibling);
    }
  }
  
  // hiddenクラスを削除（display: none !important; を解除するため）
  chartContainer.classList.remove('hidden');
  
  // ClimateChartが読み込まれていることを確認
  if (typeof window.ClimateChart === 'undefined') {
    console.error('ClimateChart not loaded');
    chartContainer.innerHTML = '<div class="climate-chart-error">チャートモジュールが読み込まれていません</div>';
    return;
  }
  
  // チャートインスタンスを作成または再利用
  if (!window.climateChartInstance) {
    window.climateChartInstance = new window.ClimateChart();
  }
  
  // チャートを表示
  window.climateChartInstance.show(cultivationId, chartContainer);
}

// 圃場を追加
function addField() {
  console.log('➕ 圃場を追加');
  console.log('📊 現在の圃場数:', window.ganttState.fieldGroups.length);
  
  // 再最適化中は操作を受け付けない
  if (window.reoptimizationInProgress) {
    console.log('⚠️ 再最適化中のため操作をブロックしました');
    return;
  }
  
  // コンテナ要素を取得（i18n用のdata属性にアクセスするため）
  const container = document.getElementById('gantt-container');
  
  // ダイアログを表示して圃場名と面積を入力
  const defaultFieldName = `${window.ganttState.fieldGroups.length + 1}`;
  console.log('📝 デフォルト圃場名:', defaultFieldName);
  
  const fieldName = prompt(container?.dataset.promptFieldName, defaultFieldName);
  if (!fieldName) {
    console.log('⚠️ 圃場名が入力されなかったためキャンセル');
    return;
  }
  
  const fieldArea = prompt(container?.dataset.promptFieldArea, '100');
  if (!fieldArea) {
    console.log('⚠️ 面積が入力されなかったためキャンセル');
    return;
  }
  
  const area = parseFloat(fieldArea);
  if (isNaN(area) || area <= 0) {
    alert(getI18nMessage('jsGanttInvalidArea', 'Please enter a valid area'));
    console.error('❌ 無効な面積:', fieldArea);
    return;
  }
  
  console.log('📤 圃場追加リクエスト:', { field_name: fieldName, field_area: area });
  
  // ローディング表示（圃場追加は最適化処理ではない）
  showLoadingOverlay(getI18nMessage('jsGanttAddingFieldLoading', 'Adding field...'));
  
  // data属性からURLを取得
  const ganttContainer = document.getElementById('gantt-chart-container');
  const url = ganttContainer?.dataset.addFieldUrl;
  
  if (!url) {
    console.error('❌ data-add-field-url属性が設定されていません');
    alert('APIエンドポイントが設定されていません。ページを再読み込みしてください。');
    return;
  }
  
  console.log('📡 API URL:', url);
  
  fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content || ''
    },
    body: JSON.stringify({
      field_name: fieldName,
      field_area: area
    })
  })
  .then(response => response.json())
  .then(data => {
    console.log('📊 API Response:', data);
    
    if (data.success) {
      console.log('✅ 圃場を追加しました');
      console.log('📊 追加された圃場:', data.field);
      
      // ローディングオーバーレイを即座に非表示
      hideLoadingOverlay();
      
      // Action Cable経由で圃場追加の更新を待機
      console.log('📡 Action Cable経由で圃場追加の更新を待機中...');
    } else {
      console.error('❌ 圃場の追加に失敗しました:', data.message);
      alert(data.message || getI18nMessage('jsGanttFieldAddFailed', 'Failed to add field'));
      hideLoadingOverlay();
    }
  })
  .catch(error => {
    console.error('❌ 圃場追加エラー:', error);
    alert(getI18nMessage('jsGanttCommunicationError', 'Communication error occurred.\nPlease try again.'));
    hideLoadingOverlay();
  });
}

// 圃場を削除
function removeField(field_id) {
  console.log('🗑️ 圃場を削除:', field_id);
  
  // 再最適化中は操作を受け付けない
  if (window.reoptimizationInProgress) {
    console.log('⚠️ 再最適化中のため操作をブロックしました');
    return;
  }
  
  // コンテナ要素を取得（i18n用のdata属性にアクセスするため）
  const container = document.getElementById('gantt-container');
  
  // 圃場削除処理中フラグを設定（競合状態を防ぐ）
  window.reoptimizationInProgress = true;
  
  // ローディング表示（圃場削除は最適化処理ではない）
  showLoadingOverlay(container?.dataset.deletingField);
  
  // data属性からURLを取得
  const ganttContainer = document.getElementById('gantt-chart-container');
  const baseUrl = ganttContainer?.dataset.removeFieldUrl;
  
  if (!baseUrl) {
    console.error('❌ data-remove-field-url属性が設定されていません');
    alert('APIエンドポイントが設定されていません。ページを再読み込みしてください。');
    return;
  }
  
  // 圃場IDをURLに置換
  const url = baseUrl.replace('PLACEHOLDER', field_id);
  
  fetch(url, {
    method: 'DELETE',
    headers: {
      'Content-Type': 'application/json',
      'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content || ''
    }
  })
  .then(response => response.json())
  .then(data => {
    console.log('📊 API Response:', data);
    
    if (data.success) {
      console.log('✅ 圃場を削除しました');
      
      // データを再取得してチャートを更新
      fetchAndUpdateChart();
    } else {
      console.error('❌ 圃場の削除に失敗しました:', data.message);
      alert(data.message || getI18nMessage('jsGanttFieldDeleteFailed', 'Failed to delete field'));
      hideLoadingOverlay();
      // 失敗時はフラグをリセット
      window.reoptimizationInProgress = false;
    }
  })
  .catch(error => {
    console.error('❌ 圃場削除エラー:', error);
    alert(getI18nMessage('jsGanttCommunicationError', 'Communication error occurred.\nPlease try again.'));
    hideLoadingOverlay();
    // エラー時はフラグをリセット
    window.reoptimizationInProgress = false;
  });
}

// デバッグ用ヘルパー関数
function debugFieldIds() {
  console.log('=== 圃場ID形式チェック ===');
  console.log('圃場グループ:', window.ganttState.fieldGroups);
  console.log('');
  console.log('圃場ID一覧:');
  window.ganttState.fieldGroups.forEach((group, index) => {
    const isValid = typeof group.fieldId === 'string' && group.fieldId.startsWith('field_');
    const status = isValid ? '✅' : '❌';
    console.log(`  ${status} [${index}] ${group.fieldName}: ${group.fieldId} (type: ${typeof group.fieldId})`);
  });
  console.log('');
  
  const allValid = window.ganttState.fieldGroups.every(g => 
    typeof g.fieldId === 'string' && g.fieldId.startsWith('field_')
  );
  
  if (allValid) {
    console.log('✅ すべてのfield_idが正しい形式です（"field_123"）');
  } else {
    console.error('❌ 不正なfield_id形式が見つかりました');
  }
  
  return {
    total: window.ganttState.fieldGroups.length,
    valid: window.ganttState.fieldGroups.filter(g => 
      typeof g.fieldId === 'string' && g.fieldId.startsWith('field_')
    ).length,
    fieldIds: window.ganttState.fieldGroups.map(g => g.fieldId)
  };
}

function debugState() {
  console.log('=== ガントチャート状態 ===');
  console.log('圃場数:', window.ganttState.fieldGroups.length);
  console.log('栽培数:', window.ganttState.cultivationData.length);
  console.log('計画ID:', window.ganttState.cultivation_plan_id);
  console.log('移動履歴:', window.ganttState.moves);
  console.log('削除ID:', window.ganttState.removedIds);
}

// ローカル日付をYYYY-MM-DD形式にフォーマットするヘルパー関数
function formatLocalDate(date) {
  if (!(date instanceof Date) || isNaN(date.getTime())) {
    return '';
  }
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

// Date inputからローカルタイムゾーンで日付を読み取るヘルパー関数
function parseLocalDate(dateString) {
  if (!dateString) {
    return null;
  }
  // YYYY-MM-DD形式の文字列をパース
  const parts = dateString.split('-');
  if (parts.length !== 3) {
    return null;
  }
  const year = parseInt(parts[0], 10);
  const month = parseInt(parts[1], 10) - 1; // 月は0ベース
  const day = parseInt(parts[2], 10);
  
  // ローカルタイムゾーンのmidnightとして解釈
  // new Date(year, month, day)はローカルタイムゾーンで解釈される
  return new Date(year, month, day);
}

// 表示範囲選択UIのイベントハンドラーを設定
function setupDisplayRangeControls(ganttContainer) {
  const displayStartDateInput = document.getElementById('display-start-date');
  const displayEndDateInput = document.getElementById('display-end-date');
  const applyButton = document.getElementById('apply-display-range');
  
  if (!displayStartDateInput || !displayEndDateInput || !applyButton) {
    // 表示範囲選択UIが存在しない場合はスキップ（public plansなど）
    return;
  }
  
  // 初期値を設定（日付が有効であることを確認）
  const displayStartDate = window.ganttState.displayStartDate;
  const displayEndDate = window.ganttState.displayEndDate;
  
  if (displayStartDate instanceof Date && !isNaN(displayStartDate.getTime())) {
    displayStartDateInput.value = formatLocalDate(displayStartDate);
  } else {
    // 無効な日付の場合は計画期間の開始日を使用
    const planStartDate = window.ganttState.planStartDate;
    if (planStartDate instanceof Date && !isNaN(planStartDate.getTime())) {
      displayStartDateInput.value = formatLocalDate(planStartDate);
      window.ganttState.displayStartDate = planStartDate;
    }
  }
  
  if (displayEndDate instanceof Date && !isNaN(displayEndDate.getTime())) {
    displayEndDateInput.value = formatLocalDate(displayEndDate);
  } else {
    // 無効な日付の場合は計画期間の終了日を使用
    const planEndDate = window.ganttState.planEndDate;
    if (planEndDate instanceof Date && !isNaN(planEndDate.getTime())) {
      displayEndDateInput.value = formatLocalDate(planEndDate);
      window.ganttState.displayEndDate = planEndDate;
    }
  }
  
  // 適用ボタンのイベントハンドラー
  applyButton.addEventListener('click', function() {
    applyDisplayRange();
  });
  
  // クイック選択ボタンのイベントハンドラー
  const quickButtons = document.querySelectorAll('.display-range-btn[data-display-range-action]');
  quickButtons.forEach(button => {
    button.addEventListener('click', function() {
      const action = this.dataset.displayRangeAction;
      handleQuickRangeAction(action);
    });
  });
}

// 表示範囲を適用する共通関数
function applyDisplayRange() {
  const displayStartDateInput = document.getElementById('display-start-date');
  const displayEndDateInput = document.getElementById('display-end-date');
  
  if (!displayStartDateInput || !displayEndDateInput) {
    return;
  }
  
  // ローカルタイムゾーンで日付を解釈
  const newStartDate = parseLocalDate(displayStartDateInput.value);
  const newEndDate = parseLocalDate(displayEndDateInput.value);
  
  // バリデーション
  if (!newStartDate || !newEndDate || isNaN(newStartDate.getTime()) || isNaN(newEndDate.getTime())) {
    alert('有効な日付を選択してください。');
    return;
  }
  
  if (newStartDate >= newEndDate) {
    alert('開始日は終了日より前である必要があります。');
    return;
  }
  
  // 計画範囲のチェックを削除：計画範囲外の期間にも作付けを作成できるようにする
  
  // 表示範囲を更新
  window.ganttState.displayStartDate = newStartDate;
  window.ganttState.displayEndDate = newEndDate;
  
  // ガントチャートを再描画
  const container = document.getElementById('gantt-chart-container');
  if (container) {
    // 計画期間は引数として渡さない（関数内で表示範囲を使用するため）
    renderGanttChart(container, window.ganttState.fieldGroups);
  }
}

// クイック選択アクションを処理
function handleQuickRangeAction(action) {
  const displayStartDateInput = document.getElementById('display-start-date');
  const displayEndDateInput = document.getElementById('display-end-date');
  
  if (!displayStartDateInput || !displayEndDateInput) {
    return;
  }
  
  const planStartDate = window.ganttState.planStartDate;
  const planEndDate = window.ganttState.planEndDate;
  
  if (!planStartDate || !planEndDate) {
    console.error('計画期間が設定されていません');
    return;
  }
  
  // 現在の表示範囲を取得（なければ計画期間全体）
  let currentStartDate = window.ganttState.displayStartDate || planStartDate;
  let currentEndDate = window.ganttState.displayEndDate || planEndDate;
  
  // 現在の表示範囲の期間を計算
  const currentRangeDays = Math.ceil((currentEndDate - currentStartDate) / (1000 * 60 * 60 * 24));
  
  let newStartDate, newEndDate;
  
  switch (action) {
    case 'month-back':
      // 1ヶ月前に移動（同じ期間を保つ）
      // 日付オーバーフローを防ぐため、月の最初の日を基準に計算
      newStartDate = new Date(currentStartDate);
      const startDay = newStartDate.getDate();
      newStartDate.setDate(1); // 月の最初の日に設定
      newStartDate.setMonth(newStartDate.getMonth() - 1);
      // 対象月の最終日を取得
      const targetMonthLastDay = new Date(newStartDate.getFullYear(), newStartDate.getMonth() + 1, 0).getDate();
      // 元の日付と対象月の最終日の小さい方を設定
      newStartDate.setDate(Math.min(startDay, targetMonthLastDay));
      newEndDate = new Date(newStartDate);
      newEndDate.setDate(newEndDate.getDate() + currentRangeDays);
      break;
      
    case 'month-forward':
      // 1ヶ月後に移動（同じ期間を保つ）
      // 日付オーバーフローを防ぐため、月の最初の日を基準に計算
      newStartDate = new Date(currentStartDate);
      const startDayForward = newStartDate.getDate();
      newStartDate.setDate(1); // 月の最初の日に設定
      newStartDate.setMonth(newStartDate.getMonth() + 1);
      // 対象月の最終日を取得
      const targetMonthLastDayForward = new Date(newStartDate.getFullYear(), newStartDate.getMonth() + 1, 0).getDate();
      // 元の日付と対象月の最終日の小さい方を設定
      newStartDate.setDate(Math.min(startDayForward, targetMonthLastDayForward));
      newEndDate = new Date(newStartDate);
      newEndDate.setDate(newEndDate.getDate() + currentRangeDays);
      break;
      
    case 'range-1year':
      // 現在の開始日から1年間の範囲を設定（開始日は変更せず、終了日を開始日から+1年）
      newStartDate = new Date(currentStartDate);
      newEndDate = new Date(currentStartDate);
      newEndDate.setFullYear(newEndDate.getFullYear() + 1);
      break;
      
    case 'range-2year':
      // 現在の開始日から2年間の範囲を設定（開始日は変更せず、終了日を開始日から+2年）
      newStartDate = new Date(currentStartDate);
      newEndDate = new Date(currentStartDate);
      newEndDate.setFullYear(newEndDate.getFullYear() + 2);
      break;
      
    case 'full-range':
      // 計画期間全体を表示
      newStartDate = new Date(planStartDate);
      newEndDate = new Date(planEndDate);
      break;
      
    default:
      console.warn('未知のアクション:', action);
      return;
  }
  
  // 計画範囲の制約を削除：計画範囲外の期間にも作付けを作成できるようにする
  // 開始日が終了日より後にならないようにバリデーション
  if (newStartDate >= newEndDate) {
    console.error('日付計算エラー: 開始日が終了日より後になっています。', {
      action: action,
      newStartDate: newStartDate,
      newEndDate: newEndDate
    });
    alert('日付計算エラーが発生しました。開始日が終了日より後になっています。');
    return;
  }
  
  // 入力フィールドを更新（ローカル日付フォーマットを使用）
  displayStartDateInput.value = formatLocalDate(newStartDate);
  displayEndDateInput.value = formatLocalDate(newEndDate);
  
  // 自動的に適用
  applyDisplayRange();
}

// 作付が表示範囲内に表示されるか判定
function shouldDisplayCultivation(cultivation) {
  if (!window.ganttState.displayStartDate || !window.ganttState.displayEndDate) {
    return true; // 表示範囲が設定されていない場合は全て表示
  }
  
  // ローカルタイムゾーンで日付を解釈
  const startDate = parseLocalDate(cultivation.start_date);
  const completionDate = parseLocalDate(cultivation.completion_date);
  const displayStartDate = window.ganttState.displayStartDate;
  const displayEndDate = window.ganttState.displayEndDate;
  
  // 無効な日付の場合は表示しない
  if (!startDate || !completionDate || !displayStartDate || !displayEndDate ||
      isNaN(startDate.getTime()) || isNaN(completionDate.getTime()) ||
      isNaN(displayStartDate.getTime()) || isNaN(displayEndDate.getTime())) {
    return false;
  }
  
  // 表示範囲と重複しているか
  return !(completionDate < displayStartDate || startDate > displayEndDate);
}

// 作付が移動可能か判定（表示範囲内に完全に収まっている場合のみ）
function isMovable(cultivation) {
  if (!window.ganttState.displayStartDate || !window.ganttState.displayEndDate) {
    return true; // 表示範囲が設定されていない場合は移動可能
  }
  
  // ローカルタイムゾーンで日付を解釈
  const startDate = parseLocalDate(cultivation.start_date);
  const completionDate = parseLocalDate(cultivation.completion_date);
  const displayStartDate = window.ganttState.displayStartDate;
  const displayEndDate = window.ganttState.displayEndDate;
  
  // 無効な日付の場合は移動不可
  if (!startDate || !completionDate || !displayStartDate || !displayEndDate ||
      isNaN(startDate.getTime()) || isNaN(completionDate.getTime()) ||
      isNaN(displayStartDate.getTime()) || isNaN(displayEndDate.getTime())) {
    return false;
  }
  
  // 表示範囲内に完全に収まっているか
  return startDate >= displayStartDate && completionDate <= displayEndDate;
}

// フィールドが空の場合のメッセージを表示
function renderEmptyFieldsMessage(container) {
  const messageDiv = document.createElement('div');
  messageDiv.className = 'gantt-empty-fields-message';
  messageDiv.innerHTML = `
    <div style="text-align: center; padding: 40px 20px; color: #6b7280;">
      <div style="font-size: 48px; margin-bottom: 16px;">📊</div>
      <h3 style="font-size: 18px; font-weight: 600; color: #374151; margin-bottom: 8px;">
        圃場データがありません
      </h3>
      <p style="font-size: 14px; color: #6b7280; margin-bottom: 16px;">
        計画の作成時に問題が発生した可能性があります。<br>
        計画を再作成するか、管理者にお問い合わせください。
      </p>
      <div style="font-size: 12px; color: #9ca3af;">
        デバッグ情報: fieldGroups.length = 0
      </div>
    </div>
  `;

  container.innerHTML = '';
  container.appendChild(messageDiv);
}

// グローバルに公開
window.initCustomGanttChart = initCustomGanttChart;
window.showClimateChart = showClimateChart;
window.addField = addField;
// normalizeFieldIdは共通ユーティリティ（gantt_data_utils.js）で管理
window.debugFieldIds = debugFieldIds;
window.debugState = debugState;

