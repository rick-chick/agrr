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
    cultivation_plan_id: null,
    cableSubscription: null, // Action Cableサブスクリプション
    // イベントハンドラーの参照を保存
    globalMouseMoveHandler: null,
    globalMouseUpHandler: null
  };
}

// normalizeFieldId関数は共通ユーティリティ（gantt_data_utils.js）に移動


// 初期化関数（遅延実行でコンテナが確実に存在することを保証）
if (typeof window.MAX_RETRIES === 'undefined') {
  window.MAX_RETRIES = 50; // 最大5秒間待機 (100ms × 50)
}

// ガントチャートが存在するページかどうかを判定
function shouldHaveGanttChart() {
  const currentPath = window.location.pathname;
  console.log('🔍 [Gantt Chart] ページ判定中:', currentPath);
  
  // ガントチャートが表示されるページのパターン
  const ganttPages = [
    '/plans/',  // 計画詳細ページ
    '/public_plans/',  // 公開計画詳細ページ
    '/results/'  // 結果ページ
  ];
  
  const shouldHave = ganttPages.some(pattern => currentPath.includes(pattern));
  console.log('🔍 [Gantt Chart] ページ判定結果:', shouldHave, 'パターン:', ganttPages);
  
  return shouldHave;
}

function initWhenReady() {
  if (typeof window.ganttRetryCount === 'undefined') {
    window.ganttRetryCount = 0;
  }
  
  console.log('🚀 [Gantt Chart] initWhenReady 開始', { retryCount: window.ganttRetryCount });
  
  const container = document.getElementById('gantt-chart-container');
  console.log('🔍 [Gantt Chart] コンテナ検索結果:', container ? '見つかった' : '見つからない');
  
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
    // 100ms待って再試行
    setTimeout(initWhenReady, 100);
  } else {
    // ガントチャートが期待されるページでない場合は正常終了
    if (!shouldHaveGanttChart()) {
      console.log('ℹ️ [Gantt Chart] This page does not require a gantt chart - skipping initialization');
      if (typeof window.ClientLogger !== 'undefined') {
        window.ClientLogger.info('ℹ️ [Gantt Chart] This page does not require a gantt chart - skipping initialization');
      }
    } else {
      console.log('ℹ️ [Gantt Chart] Container not found - this page may not have a gantt chart');
      if (typeof window.ClientLogger !== 'undefined') {
        window.ClientLogger.info('ℹ️ [Gantt Chart] Container not found - this page may not have a gantt chart');
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
  console.log('🔧 [Gantt Chart] スクリプト読み込み完了');

  function triggerInit() {
    console.log('🔄 [Gantt Chart] 初期化トリガー起動');
    setTimeout(initWhenReady, 50);
  }

  // 初回読み込み時（DOMが既に読み込まれている場合）
  if (document.readyState !== 'loading') {
    console.log('🔄 [Gantt Chart] 既にDOM読み込み済み、即座に初期化');
    triggerInit();
  }

  if (typeof Turbo !== 'undefined') {
    console.log('🔧 [Gantt Chart] Turbo環境を検出、イベントリスナー登録中...');
    
    // Frameレンダリング後に初期化（重複を避けるためこれのみ使用）
    document.addEventListener('turbo:frame-render', () => {
      console.log('🔄 [Gantt Chart] turbo:frame-render イベント検出');
      triggerInit();
    });
    
    // ページキャッシュ前にクリーンアップ
    document.addEventListener('turbo:before-cache', () => {
      console.log('🧹 [Gantt Chart] turbo:before-cache 検出 - クリーンアップを実行');
      cleanupGanttChart();
    });
  }
})();

function initCustomGanttChart() {
  console.log('🚀 [Gantt] initCustomGanttChart 開始');
  if (typeof window.ClientLogger !== 'undefined') {
    window.ClientLogger.warn('🚀 [Gantt] initCustomGanttChart 開始');
  }
  
  const ganttContainer = document.getElementById('gantt-chart-container');
  if (!ganttContainer) {
    console.warn('⚠️ [Gantt] gantt-chart-container が見つかりません');
    if (typeof window.ClientLogger !== 'undefined') {
      window.ClientLogger.warn('⚠️ [Gantt] gantt-chart-container が見つかりません');
    }
    return;
  }

  console.log('📊 [Gantt] データ属性を取得中...');
  // データ属性からJSONを取得
  const cultivationsRaw = JSON.parse(ganttContainer.dataset.cultivations || '[]');
  const fieldsDataRaw = JSON.parse(ganttContainer.dataset.fields || '[]');
  window.ganttState.planStartDate = new Date(ganttContainer.dataset.planStartDate);
  window.ganttState.planEndDate = new Date(ganttContainer.dataset.planEndDate);
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
    
    // SVGガントチャートを描画
    console.log('🎨 [Gantt] チャート描画開始...');
    renderGanttChart(ganttContainer, window.ganttState.fieldGroups, window.ganttState.planStartDate, window.ganttState.planEndDate);
    console.log('✅ [Gantt] チャート描画完了');
    
    // 初期化フラグをリセット
    window.ganttRetryCount = 0;
    console.log('✅ [Gantt Chart] 初期化完了、フラグをリセットしました');
  } catch (error) {
    console.error('❌ [Gantt] データ正規化エラー:', error);
    console.error('❌ [Gantt] スタックトレース:', error.stack);
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
    alert(container?.dataset.apiEndpointMissing || 'APIエンドポイントが設定されていません。ページを再読み込みしてください。');
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
        renderGanttChart(ganttContainer, window.ganttState.fieldGroups, window.ganttState.planStartDate, window.ganttState.planEndDate);
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
      window.reoptimizationInProgress = false;
    }
  })
  .catch(error => {
    console.error('❌ データ取得エラー:', error);
    alert(getI18nMessage('jsGanttFetchError', 'Error occurred while fetching data. Please reload the page manually.'));
    hideLoadingOverlay();
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
      console.warn('⚠️ cultivation.field_idが未定義です:', cultivation);
      return;
    }
    
    // field_idでグループを検索
    if (!groups[fieldId]) {
      console.warn('⚠️ field_idに対応する圃場が見つかりません:', fieldId);
      // 圃場が見つからない場合は新しいグループを作成
      groups[fieldId] = {
        fieldName: cultivation.field_name || `圃場${fieldId}`,
        fieldId: fieldId,
        cultivations: []
      };
    }
    groups[fieldId].cultivations.push(cultivation);
  });
  
  // 栽培を開始日順にソート
  Object.values(groups).forEach(group => {
    group.cultivations.sort((a, b) => new Date(a.start_date) - new Date(b.start_date));
  });
  
  return Object.values(groups);
}

// SVGガントチャートを描画
function renderGanttChart(container, fieldGroups, planStartDate, planEndDate) {
  const config = {
    width: 1200,
    height: 60 + (fieldGroups.length * 80) + 50, // ヘッダー + 行数 + 圃場追加ボタン分
    margin: { top: 60, right: 40, bottom: 20, left: 80 },
    rowHeight: 70,
    barHeight: 50,
    barPadding: 10
  };

  // 日付の検証と変換
  const startDate = typeof planStartDate === 'string' ? new Date(planStartDate) : planStartDate;
  const endDate = typeof planEndDate === 'string' ? new Date(planEndDate) : planEndDate;
  
  // 無効な日付の場合はデフォルト値を設定
  if (isNaN(startDate.getTime()) || isNaN(endDate.getTime())) {
    console.warn('Invalid dates in renderGanttChart:', { planStartDate, planEndDate });
    const now = new Date();
    const defaultStart = new Date(now.getFullYear(), 0, 1); // 今年の1月1日
    const defaultEnd = new Date(now.getFullYear(), 11, 31); // 今年の12月31日
    startDate = defaultStart;
    endDate = defaultEnd;
  }

  const totalDays = daysBetween(startDate, endDate);
  const chartWidth = config.width - config.margin.left - config.margin.right;
  const chartHeight = config.height - config.margin.top - config.margin.bottom;
  
  // chartWidthがNaNの場合はデフォルト値を設定
  if (isNaN(chartWidth) || chartWidth <= 0) {
    console.warn('Invalid chartWidth:', chartWidth);
    config.width = 1200;
    const fallbackChartWidth = config.width - config.margin.left - config.margin.right;
    console.log('Using fallback chartWidth:', fallbackChartWidth);
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
  renderTimelineHeader(svg, config, planStartDate, planEndDate, totalDays, chartWidth);

  // 各圃場の行を描画
  fieldGroups.forEach((group, index) => {
    const y = config.margin.top + (index * config.rowHeight);
    renderFieldRow(svg, config, group, index, y, planStartDate, totalDays, chartWidth);
  });
  
  // 圃場追加ボタンを描画（最後の行の下）
  const addFieldBtnY = config.margin.top + (fieldGroups.length * config.rowHeight) + 10;
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
  setupGlobalDragHandlers(svg, config, planStartDate, totalDays, chartWidth);
  
  // カスタムイベントを発火（ガントチャート初期化完了を通知）
  const ganttReadyEvent = new CustomEvent('ganttChartReady', {
    detail: { ganttState: ganttState }
  });
  document.dispatchEvent(ganttReadyEvent);
}

// グローバルなドラッグハンドラーを設定
function setupGlobalDragHandlers(svg, config, planStartDate, totalDays, chartWidth) {
  const dragThreshold = 5; // 5px以上移動したらドラッグとみなす
  
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
    const ROW_HEIGHT = 70;
    const originalBarY = parseFloat(cachedBarBg.getAttribute('data-original-y'));
    const deltaY = newY - originalBarY;
    const fieldIndexChange = Math.round(deltaY / ROW_HEIGHT);
    const targetFieldIndex = Math.max(0, Math.min(
      window.ganttState.originalFieldIndex + fieldIndexChange,
      window.ganttState.fieldGroups.length - 1
    ));
    
    // ハイライトの更新（圃場が変わった場合のみ）
    if (targetFieldIndex !== lastTargetFieldIndex) {
      const HEADER_HEIGHT = 60;
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
    const ROW_HEIGHT = 70;
    const MARGIN_LEFT = 80;
    
    let newX, newFieldIndex, newFieldName, daysFromStart, newStartDate;
    
    if (cachedBarBg) {
      // 現在のSVG座標から計算
      newX = parseFloat(cachedBarBg.getAttribute('x'));
      const currentY = parseFloat(cachedBarBg.getAttribute('y'));
      const originalBarY = parseFloat(cachedBarBg.getAttribute('data-original-y'));
      
      // 日付計算
      const svg = document.querySelector('svg.custom-gantt-chart');
      const chartWidth = svg ? parseFloat(svg.getAttribute('width')) - MARGIN_LEFT - 40 : 1080;
      const totalDays = daysBetween(window.ganttState.planStartDate, window.ganttState.planEndDate);
      daysFromStart = Math.round((newX - MARGIN_LEFT) / chartWidth * totalDays);
      newStartDate = new Date(window.ganttState.planStartDate);
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
      newStartDate = window.ganttState.planStartDate;
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
          new_start_date: newStartDate.toISOString().split('T')[0],
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
    to_start_date: to_start_date.toISOString().split('T')[0]
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
    renderGanttChart(ganttContainer, window.ganttState.fieldGroups, window.ganttState.planStartDate, window.ganttState.planEndDate);
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
      const oldStartDate = new Date(cultivation.start_date);
      const oldEndDate = new Date(cultivation.completion_date);
      const duration = daysBetween(oldStartDate, oldEndDate);
      
      // 楽観的更新: ユーザーが指定した開始日と、元の期間を維持した終了日
      // ⭐ adjustの実際の結果では、開始日も終了日も変わる可能性がある
      const newStartDate = new Date(move.to_start_date);
      const newEndDate = new Date(newStartDate);
      newEndDate.setDate(newEndDate.getDate() + duration);
      
      // 開始日と終了日の両方を更新
      cultivation.start_date = newStartDate.toISOString().split('T')[0];
      cultivation.completion_date = newEndDate.toISOString().split('T')[0];
      
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
    renderGanttChart(ganttContainer, window.ganttState.fieldGroups, window.ganttState.planStartDate, window.ganttState.planEndDate);
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
    alert(container?.dataset.apiEndpointMissing || 'APIエンドポイントが設定されていません。ページを再読み込みしてください。');
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
      } else if (userMessage.includes('Cannot complete growth') || userMessage.includes('planning period')) {
        userMessage = '移動先の日付では、計画期間内に成長が完了しません。\nより早い日付を選択してください。';
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
function renderFieldRow(svg, config, group, index, y, planStartDate, totalDays, chartWidth) {
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

  // 各栽培のバーを描画
  group.cultivations.forEach((cultivation, cultIndex) => {
    renderCultivationBar(rowGroup, config, cultivation, y, planStartDate, totalDays, chartWidth);
  });

  svg.appendChild(rowGroup);
}

// 栽培バーを描画
// ⭐ ガントカードの位置と幅は、開始日と終了日の両方から計算される
function renderCultivationBar(parentGroup, config, cultivation, rowY, planStartDate, totalDays, chartWidth) {
  // 開始日と終了日を取得
  const startDate = new Date(cultivation.start_date);
  const endDate = new Date(cultivation.completion_date);
  
  // 無効な日付の場合はスキップ
  if (isNaN(startDate.getTime()) || isNaN(endDate.getTime())) {
    console.warn('Invalid cultivation dates:', { cultivation, startDate, endDate });
    return;
  }
  
  // 日数計算で無効な値が返された場合はスキップ
  const daysFromStart = daysBetween(planStartDate, startDate);
  const cultivationDays = daysBetween(startDate, endDate) + 1;
  
  if (daysFromStart < 0 || cultivationDays <= 0) {
    console.warn('Invalid cultivation period calculation:', { 
      cultivation, 
      daysFromStart, 
      cultivationDays,
      planStartDate,
      startDate,
      endDate
    });
    return;
  }
  
  // 日数ベースの座標計算
  // ⭐ barXは開始日から計算される（adjustで開始日が変わると位置も変わる）
  // ⭐ barWidthは開始日と終了日から計算される（adjustで期間が変わると幅も変わる）
  
  const barX = config.margin.left + (daysFromStart / totalDays) * chartWidth;
  const barWidth = (cultivationDays / totalDays) * chartWidth;
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
    style: 'cursor: grab;',
    opacity: '0.95'
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
    this.style.cursor = 'grab';
  });
  
  barBg.addEventListener('mouseleave', function() {
    if (window.ganttState.draggedBar !== barGroup) {
      this.setAttribute('opacity', '0.95');
      this.setAttribute('stroke-width', '2.5');
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

// 2つの日付間の日数を計算
function daysBetween(date1, date2) {
  // 日付をDateオブジェクトに変換（文字列の場合は変換）
  const d1 = typeof date1 === 'string' ? new Date(date1) : date1;
  const d2 = typeof date2 === 'string' ? new Date(date2) : date2;
  
  // 無効な日付の場合は0を返す（描画をスキップするため）
  if (isNaN(d1.getTime()) || isNaN(d2.getTime())) {
    console.warn('Invalid date in daysBetween:', { date1, date2, d1, d2 });
    return 0; // 無効な日付の場合は0を返して描画をスキップ
  }
  
  const oneDay = 24 * 60 * 60 * 1000;
  const result = Math.round(Math.abs((d2 - d1) / oneDay));
  
  // 結果が0以下の場合は最小値を返す
  return Math.max(result, 1);
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
  
  // ダイアログを表示して圃場名と面積を入力
  const defaultFieldName = `${window.ganttState.fieldGroups.length + 1}`;
  console.log('📝 デフォルト圃場名:', defaultFieldName);
  
  const fieldName = prompt(container?.dataset.promptFieldName || '圃場名を入力してください（例: 4）', defaultFieldName);
  if (!fieldName) {
    console.log('⚠️ 圃場名が入力されなかったためキャンセル');
    return;
  }
  
  const fieldArea = prompt(container?.dataset.promptFieldArea || '面積（㎡）を入力してください', '100');
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
  
  // 圃場削除処理中フラグを設定（競合状態を防ぐ）
  window.reoptimizationInProgress = true;
  
  // ローディング表示（圃場削除は最適化処理ではない）
  showLoadingOverlay(container?.dataset.deletingField || '圃場を削除中...');
  
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
  console.log('');
  debugFieldIds();
}

// グローバルに公開
window.initCustomGanttChart = initCustomGanttChart;
window.showClimateChart = showClimateChart;
window.addField = addField;
// normalizeFieldIdは共通ユーティリティ（gantt_data_utils.js）で管理
window.debugFieldIds = debugFieldIds;
window.debugState = debugState;

