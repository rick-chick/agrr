// app/javascript/custom_gantt_chart.js
// カスタムSVGガントチャート（圃場ベース）- ドラッグ&ドロップ対応

// グローバルステート管理
let ganttState = {
  cultivationData: [],
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
  dragStartX: 0,
  dragStartY: 0,
  originalBarX: 0,
  originalFieldIndex: -1,
  cultivation_plan_id: null
};

document.addEventListener('DOMContentLoaded', () => {
  initCustomGanttChart();
});

document.addEventListener('turbo:load', () => {
  initCustomGanttChart();
});

function initCustomGanttChart() {
  const ganttContainer = document.getElementById('gantt-chart-container');
  if (!ganttContainer) return;

  // データ属性からJSONを取得
  ganttState.cultivationData = JSON.parse(ganttContainer.dataset.cultivations || '[]');
  ganttState.planStartDate = new Date(ganttContainer.dataset.planStartDate);
  ganttState.planEndDate = new Date(ganttContainer.dataset.planEndDate);
  ganttState.cultivation_plan_id = ganttContainer.dataset.cultivationPlanId;
  
  // 移動履歴と削除IDをリセット
  ganttState.moves = [];
  ganttState.removedIds = [];

  if (ganttState.cultivationData.length === 0) {
    ganttContainer.innerHTML = '<p style="text-align: center; padding: 2rem; color: #999;">栽培データがありません</p>';
    return;
  }

  console.log('🎨 Custom Gantt Chart 初期化中...');
  console.log('  栽培数:', ganttState.cultivationData.length);
  console.log('  期間:', ganttState.planStartDate, 'to', ganttState.planEndDate);
  console.log('  計画ID:', ganttState.cultivation_plan_id);
  
  // デバッグ用: ドラッグ&ドロップ機能の有効化を確認
  console.log('🔧 ドラッグ&ドロップ機能を有効化しました');
  console.log('  - バーをドラッグして移動できます');
  console.log('  - ×ボタンで削除できます');
  console.log('  - 右クリックで削除できます');

  // 圃場ごとにグループ化
  ganttState.fieldGroups = groupByField(ganttState.cultivationData);
  
  // SVGガントチャートを描画
  renderGanttChart(ganttContainer, ganttState.fieldGroups, ganttState.planStartDate, ganttState.planEndDate);
}

// 圃場ごとにグループ化
function groupByField(cultivations) {
  const groups = {};
  
  cultivations.forEach(cultivation => {
    const fieldName = cultivation.field_name || '未設定';
    if (!groups[fieldName]) {
      groups[fieldName] = {
        fieldName: fieldName,
        cultivations: []
      };
    }
    groups[fieldName].cultivations.push(cultivation);
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
    height: 60 + (fieldGroups.length * 80), // ヘッダー + 行数（余裕を持たせる）
    margin: { top: 60, right: 40, bottom: 20, left: 80 },
    rowHeight: 70,
    barHeight: 50,
    barPadding: 10
  };

  const totalDays = daysBetween(planStartDate, planEndDate);
  const chartWidth = config.width - config.margin.left - config.margin.right;
  const chartHeight = config.height - config.margin.top - config.margin.bottom;
  
  // グローバルステートに保存
  ganttState.config = config;
  ganttState.chartWidth = chartWidth;
  ganttState.chartHeight = chartHeight;
  ganttState.totalDays = totalDays;

  console.log('📐 チャート寸法:', {
    totalDays,
    chartWidth,
    chartHeight,
    fields: fieldGroups.length
  });

  // SVG要素を作成
  const svg = createSVGElement('svg', {
    width: config.width,
    height: config.height,
    class: 'custom-gantt-chart',
    viewBox: `0 0 ${config.width} ${config.height}`
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

  // 背景
  svg.appendChild(createSVGElement('rect', {
    width: config.width,
    height: config.height,
    fill: 'url(#bgGradient)'
  }));

  // タイムラインヘッダーを描画
  renderTimelineHeader(svg, config, planStartDate, planEndDate, totalDays, chartWidth);

  // 各圃場の行を描画
  fieldGroups.forEach((group, index) => {
    const y = config.margin.top + (index * config.rowHeight);
    renderFieldRow(svg, config, group, index, y, planStartDate, totalDays, chartWidth);
  });

  // コンテナをクリアしてSVGを追加
  container.innerHTML = '';
  container.appendChild(svg);
  
  // グローバルなマウスイベントリスナーを追加
  setupGlobalDragHandlers(svg, config, planStartDate, totalDays, chartWidth);
  
  // 再最適化ボタンは不要（自動実行のため）
  
  console.log('✅ ガントチャート描画完了');
  
  // デバッグ: バーの数とイベントリスナーを確認
  const bars = document.querySelectorAll('.cultivation-bar .bar-bg');
  console.log('📊 描画されたバー数:', bars.length);
  
  bars.forEach((bar, index) => {
    console.log(`📊 バー ${index + 1}:`, {
      element: bar,
      hasMousedownListener: bar.onmousedown !== null,
      cursor: bar.style.cursor
    });
  });
}

// グローバルなドラッグハンドラーを設定
function setupGlobalDragHandlers(svg, config, planStartDate, totalDays, chartWidth) {
  // マウス移動（ドラッグ中）
  document.addEventListener('mousemove', function(e) {
    if (!ganttState.draggedBar) return;
    
    const deltaX = e.clientX - ganttState.dragStartX;
    const deltaY = e.clientY - ganttState.dragStartY;
    
    // 新しいX位置を計算（グラフの範囲内に制限）
    const newX = Math.max(
      config.margin.left,
      Math.min(
        ganttState.originalBarX + deltaX,
        config.margin.left + chartWidth
      )
    );
    
    // バーの位置を更新
    const barBg = ganttState.draggedBar.querySelector('.bar-bg');
    if (barBg) {
      barBg.setAttribute('x', newX);
      
      // ラベルと削除ボタンの位置も更新
      const barWidth = parseFloat(barBg.getAttribute('width'));
      const label = ganttState.draggedBar.querySelector('.bar-label');
      if (label) {
        label.setAttribute('x', newX + (barWidth / 2));
      }
      
      const deleteBtn = ganttState.draggedBar.querySelector('.delete-btn circle');
      const deleteBtnText = ganttState.draggedBar.querySelector('.delete-btn text');
      if (deleteBtn && deleteBtnText) {
        deleteBtn.setAttribute('cx', newX + barWidth - 10);
        deleteBtnText.setAttribute('x', newX + barWidth - 10);
      }
    }
  });
  
  // マウスアップ（ドラッグ終了）
  document.addEventListener('mouseup', function(e) {
    if (!ganttState.draggedBar) return;
    
    const cultivation_id = ganttState.draggedBar.getAttribute('data-id');
    const originalFieldName = ganttState.draggedBar.getAttribute('data-field');
    
    // 新しい開始日を計算
    const barBg = ganttState.draggedBar.querySelector('.bar-bg');
    if (!barBg) {
      ganttState.draggedBar = null;
      return;
    }
    
    const newX = parseFloat(barBg.getAttribute('x'));
    const daysFromStart = Math.round((newX - config.margin.left) / chartWidth * totalDays);
    const newStartDate = new Date(planStartDate);
    newStartDate.setDate(newStartDate.getDate() + daysFromStart);
    
    // Y方向の移動から新しい圃場を判定
    const deltaY = e.clientY - ganttState.dragStartY;
    const fieldIndexChange = Math.round(deltaY / config.rowHeight);
    const newFieldIndex = Math.max(0, Math.min(
      ganttState.originalFieldIndex + fieldIndexChange,
      ganttState.fieldGroups.length - 1
    ));
    
    const newFieldName = ganttState.fieldGroups[newFieldIndex].fieldName;
    
    // 移動があった場合のみ記録
    if (originalFieldName !== newFieldName || Math.abs(daysFromStart) > 2) {
      console.log('📍 ドラッグ完了:', {
        cultivation_id,
        from_field: originalFieldName,
        to_field: newFieldName,
        new_start_date: newStartDate.toISOString().split('T')[0]
      });
      
      // 移動履歴に追加
      recordMove(cultivation_id, newFieldName, newStartDate);
      
      // チャートを再描画（変更を反映）
      applyMovesLocally();
      
      // 自動で再最適化を実行
      executeReoptimization();
    }
    
    // ドラッグ状態をリセット
    barBg.style.cursor = 'grab';
    barBg.setAttribute('opacity', '0.95');
    barBg.setAttribute('stroke-width', '2.5');
    barBg.removeAttribute('stroke-dasharray');
    ganttState.draggedBar = null;
  });
}

// 移動を記録
function recordMove(allocation_id, to_field_name, to_start_date) {
  // 既存の移動を削除（同じIDの場合）
  ganttState.moves = ganttState.moves.filter(m => m.allocation_id !== `alloc_${allocation_id}`);
  
  // 圃場IDを抽出
  const fieldGroup = ganttState.fieldGroups.find(g => g.fieldName === to_field_name);
  const field_id = `field_${fieldGroup?.cultivations[0]?.field_name?.match(/\d+/)?.[0] || '1'}`;
  
  ganttState.moves.push({
    allocation_id: `alloc_${allocation_id}`,
    action: 'move',
    to_field_id: field_id,
    to_start_date: to_start_date.toISOString().split('T')[0]
  });
  
  console.log('📋 移動履歴:', ganttState.moves);
  
  // 自動で再最適化を実行
  executeReoptimization();
}

// 削除を実行
function removeCultivation(cultivation_id) {
  console.log('🗑️ 削除:', cultivation_id);
  
  // 削除IDを記録
  ganttState.removedIds.push(cultivation_id);
  
  // 移動履歴に削除を追加
  ganttState.moves.push({
    allocation_id: `alloc_${cultivation_id}`,
    action: 'remove'
  });
  
  // ローカルで削除を適用
  ganttState.cultivationData = ganttState.cultivationData.filter(c => c.id != cultivation_id);
  ganttState.fieldGroups = groupByField(ganttState.cultivationData);
  
  // チャートを再描画
  const ganttContainer = document.getElementById('gantt-chart-container');
  if (ganttContainer) {
    renderGanttChart(ganttContainer, ganttState.fieldGroups, ganttState.planStartDate, ganttState.planEndDate);
  }
  
  // 自動で再最適化を実行
  executeReoptimization();
}

// ローカルで移動を適用（再描画用）
function applyMovesLocally() {
  // 移動を適用
  ganttState.moves.filter(m => m.action === 'move').forEach(move => {
    const cultivation_id = parseInt(move.allocation_id.replace('alloc_', ''));
    const cultivation = ganttState.cultivationData.find(c => c.id === cultivation_id);
    
    if (cultivation) {
      const oldStartDate = new Date(cultivation.start_date);
      const oldEndDate = new Date(cultivation.completion_date);
      const duration = daysBetween(oldStartDate, oldEndDate);
      
      const newStartDate = new Date(move.to_start_date);
      const newEndDate = new Date(newStartDate);
      newEndDate.setDate(newEndDate.getDate() + duration);
      
      cultivation.start_date = newStartDate.toISOString().split('T')[0];
      cultivation.completion_date = newEndDate.toISOString().split('T')[0];
      
      // 圃場名を更新（簡易版 - 実際にはfield_idからフィールド名を取得すべき）
      const fieldNum = move.to_field_id.replace('field_', '');
      cultivation.field_name = `圃場 ${fieldNum}`;
    }
  });
  
  // 削除を適用
  ganttState.cultivationData = ganttState.cultivationData.filter(c => 
    !ganttState.removedIds.includes(c.id)
  );
  
  // 再グループ化
  ganttState.fieldGroups = groupByField(ganttState.cultivationData);
  
  // 再描画
  const ganttContainer = document.getElementById('gantt-chart-container');
  if (ganttContainer) {
    renderGanttChart(ganttContainer, ganttState.fieldGroups, ganttState.planStartDate, ganttState.planEndDate);
  }
}

// 手動の再最適化ボタンは不要（自動実行のため）

// 再最適化を実行（自動実行）
function executeReoptimization() {
  console.log('🔄 自動再最適化を開始...');
  
  // APIエンドポイントにPOST
  const url = `/api/v1/public_plans/cultivation_plans/${ganttState.cultivation_plan_id}/adjust`;
  
  // 一時的に再最適化を無効化（APIエラーのため）
  console.log('⚠️ 再最適化は一時的に無効化されています（APIエラー修正中）');
  console.log('📋 移動履歴:', ganttState.moves);
  
  // 移動履歴をクリア
  ganttState.moves = [];
  
  // TODO: APIエラーが修正されたら再最適化を有効化
  /*
  fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content || ''
    },
    body: JSON.stringify({
      moves: ganttState.moves
    })
  })
  .then(response => response.json())
  .then(data => {
    if (data.success) {
      console.log('✅ 再最適化が完了しました。ページをリロードします。');
      location.reload();
    } else {
      console.error('❌ 再最適化に失敗しました:', data.message);
      alert(`再最適化に失敗しました: ${data.message}`);
    }
  })
  .catch(error => {
    console.error('❌ 再最適化エラー:', error);
    alert(`エラーが発生しました: ${error.message}`);
  });
  */
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

    // 月の境界線
    headerGroup.appendChild(createSVGElement('line', {
      x1: currentX,
      y1: 40,
      x2: currentX,
      y2: config.height - config.margin.bottom,
      stroke: '#E5E7EB',
      'stroke-width': '1'
    }));

    currentX += monthWidth;
  });

  svg.appendChild(headerGroup);
}

// 圃場行を描画
function renderFieldRow(svg, config, group, index, y, planStartDate, totalDays, chartWidth) {
  const rowGroup = createSVGElement('g', {
    class: 'field-row',
    'data-field': group.fieldName
  });

  // 背景（偶数行）
  if (index % 2 === 0) {
    rowGroup.appendChild(createSVGElement('rect', {
      x: 0,
      y: y,
      width: config.width,
      height: config.rowHeight,
      fill: '#F9FAFB'
    }));
  }

  // 圃場ラベル（左側）
  const fieldNumber = group.fieldName.replace(/[^\d]/g, '');
  rowGroup.appendChild(createSVGElement('text', {
    x: 30,
    y: y + (config.rowHeight / 2) + 5,
    class: 'field-label',
    'text-anchor': 'middle',
    'font-size': '14',
    'font-weight': '600',
    fill: '#374151'
  }, fieldNumber));

  // 圃場列の右端線
  rowGroup.appendChild(createSVGElement('line', {
    x1: config.margin.left - 10,
    y1: y,
    x2: config.margin.left - 10,
    y2: y + config.rowHeight,
    stroke: '#D1D5DB',
    'stroke-width': '2'
  }));

  // 各栽培のバーを描画
  group.cultivations.forEach((cultivation, cultIndex) => {
    console.log('🎯 栽培バーを描画中:', cultivation.crop_name);
    renderCultivationBar(rowGroup, config, cultivation, y, planStartDate, totalDays, chartWidth);
  });

  svg.appendChild(rowGroup);
}

// 栽培バーを描画
function renderCultivationBar(parentGroup, config, cultivation, rowY, planStartDate, totalDays, chartWidth) {
  console.log('🎨 栽培バー描画開始:', cultivation.crop_name, cultivation.start_date, cultivation.completion_date);
  
  const startDate = new Date(cultivation.start_date);
  const endDate = new Date(cultivation.completion_date);
  
  // 日数ベースの座標計算
  const daysFromStart = daysBetween(planStartDate, startDate);
  const cultivationDays = daysBetween(startDate, endDate) + 1; // 開始日を含む
  
  const barX = config.margin.left + (daysFromStart / totalDays) * chartWidth;
  const barWidth = (cultivationDays / totalDays) * chartWidth;
  const barY = rowY + config.barPadding;
  
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
    fill: getCropColor(cultivation.crop_name),
    stroke: getCropStrokeColor(cultivation.crop_name),
    'stroke-width': '2.5',
    class: 'bar-bg',
    style: 'cursor: grab;',
    opacity: '0.95'
  });

  // ホバー効果を追加
  barBg.addEventListener('mouseenter', function() {
    this.setAttribute('opacity', '1');
    this.setAttribute('stroke-width', '3.5');
    
    // ドラッグ可能であることを示すカーソル
    this.style.cursor = 'grab';
  });
  
  barBg.addEventListener('mouseleave', function() {
    if (ganttState.draggedBar !== barGroup) {
      this.setAttribute('opacity', '0.95');
      this.setAttribute('stroke-width', '2.5');
    }
  });
  
  barGroup.appendChild(barBg);

  // ドラッグとクリックを区別するための変数
  let isDragging = false;
  let dragThreshold = 5; // 5px以上移動したらドラッグとみなす
  let mouseDownTime = 0;
  let clickTimeout = null;

  // ドラッグ開始
  barBg.addEventListener('mousedown', function(e) {
    // 右クリックは除外
    if (e.button !== 0) return;
    
    isDragging = false;
    mouseDownTime = Date.now();
    ganttState.dragStartX = e.clientX;
    ganttState.dragStartY = e.clientY;
    ganttState.originalBarX = parseFloat(barBg.getAttribute('x'));
    
    // 現在のフィールドインデックスを保存
    const currentFieldName = cultivation.field_name;
    ganttState.originalFieldIndex = ganttState.fieldGroups.findIndex(g => g.fieldName === currentFieldName);
    
    console.log('🖱️ マウスダウン:', cultivation.crop_name);
  });

  // マウス移動（ドラッグ判定）
  barBg.addEventListener('mousemove', function(e) {
    if (mouseDownTime === 0) return;
    
    const deltaX = Math.abs(e.clientX - ganttState.dragStartX);
    const deltaY = Math.abs(e.clientY - ganttState.dragStartY);
    
    if (deltaX > dragThreshold || deltaY > dragThreshold) {
      if (!isDragging) {
        isDragging = true;
        ganttState.draggedBar = barGroup;
        
        // クリックタイムアウトをクリア
        if (clickTimeout) {
          clearTimeout(clickTimeout);
          clickTimeout = null;
        }
        
        this.style.cursor = 'grabbing';
        console.log('🖱️ ドラッグ開始:', cultivation.crop_name);
        
        // ドラッグ可能であることを視覚的に示す
        this.setAttribute('opacity', '0.8');
        this.setAttribute('stroke-width', '4');
        this.setAttribute('stroke-dasharray', '5,5');
      }
    }
  });

  // マウスアップ（クリック判定）
  barBg.addEventListener('mouseup', function(e) {
    if (mouseDownTime === 0) return;
    
    const clickDuration = Date.now() - mouseDownTime;
    mouseDownTime = 0;
    
    if (!isDragging && clickDuration < 300) {
      // クリック処理
      console.log('🖱️ クリック:', cultivation.crop_name);
      showClimateChart(cultivation.id);
    }
    
    isDragging = false;
    ganttState.draggedBar = null;
    
    // 視覚的効果をリセット
    this.style.cursor = 'grab';
    this.setAttribute('opacity', '1');
    this.setAttribute('stroke-width', '2');
    this.setAttribute('stroke-dasharray', '');
  });

  // 右クリック（コンテキストメニュー）で削除
  barBg.addEventListener('contextmenu', function(e) {
    e.preventDefault();
    e.stopPropagation();
    
    if (confirm(`${cultivation.crop_name}を削除しますか？`)) {
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
    
    if (confirm(`${cultivation.crop_name}を削除しますか？`)) {
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
  const oneDay = 24 * 60 * 60 * 1000;
  return Math.round(Math.abs((date2 - date1) / oneDay));
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

// 作物の色パレット（順番に使用）
const colorPalette = [
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

// 作物名をハッシュ化して色インデックスを決定
const cropColorMap = new Map();

function getCropColor(cropName) {
  const baseCropName = cropName.split('（')[0];
  
  if (!cropColorMap.has(baseCropName)) {
    // 新しい作物の場合、次の色を割り当て
    const colorIndex = cropColorMap.size % colorPalette.length;
    cropColorMap.set(baseCropName, colorIndex);
  }
  
  const colorIndex = cropColorMap.get(baseCropName);
  return colorPalette[colorIndex].fill;
}

function getCropStrokeColor(cropName) {
  const baseCropName = cropName.split('（')[0];
  
  if (!cropColorMap.has(baseCropName)) {
    const colorIndex = cropColorMap.size % colorPalette.length;
    cropColorMap.set(baseCropName, colorIndex);
  }
  
  const colorIndex = cropColorMap.get(baseCropName);
  return colorPalette[colorIndex].stroke;
}

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

// グローバルに公開
window.initCustomGanttChart = initCustomGanttChart;
window.showClimateChart = showClimateChart;

