// app/javascript/custom_gantt_chart.js
// カスタムSVGガントチャート（圃場ベース）

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
  const cultivationData = JSON.parse(ganttContainer.dataset.cultivations || '[]');
  const planStartDate = new Date(ganttContainer.dataset.planStartDate);
  const planEndDate = new Date(ganttContainer.dataset.planEndDate);

  if (cultivationData.length === 0) {
    ganttContainer.innerHTML = '<p style="text-align: center; padding: 2rem; color: #999;">栽培データがありません</p>';
    return;
  }

  console.log('🎨 Custom Gantt Chart 初期化中...');
  console.log('  栽培数:', cultivationData.length);
  console.log('  期間:', planStartDate, 'to', planEndDate);

  // 圃場ごとにグループ化
  const fieldGroups = groupByField(cultivationData);
  
  // SVGガントチャートを描画
  renderGanttChart(ganttContainer, fieldGroups, planStartDate, planEndDate);
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
  
  console.log('✅ ガントチャート描画完了');
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

    // 月ラベル
    headerGroup.appendChild(createSVGElement('text', {
      x: currentX + (monthWidth / 2),
      y: 30,
      class: 'month-label',
      'text-anchor': 'middle',
      'font-size': '13',
      'font-weight': '600',
      fill: '#1F2937'
    }, `${month.month}月`));

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
    renderCultivationBar(rowGroup, config, cultivation, y, planStartDate, totalDays, chartWidth);
  });

  svg.appendChild(rowGroup);
}

// 栽培バーを描画
function renderCultivationBar(parentGroup, config, cultivation, rowY, planStartDate, totalDays, chartWidth) {
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
    style: 'cursor: pointer;',
    opacity: '0.95'
  });

  // ホバー効果を追加
  barBg.addEventListener('mouseenter', function() {
    this.setAttribute('opacity', '1');
    this.setAttribute('stroke-width', '3.5');
  });
  
  barBg.addEventListener('mouseleave', function() {
    this.setAttribute('opacity', '0.95');
    this.setAttribute('stroke-width', '2.5');
  });

  // クリックイベント
  barBg.addEventListener('click', function(e) {
    // 既存のポップアップを削除
    const existingPopup = document.querySelector('.gantt-custom-popup');
    if (existingPopup) {
      existingPopup.remove();
    }
    
    // 気温・GDDチャートを表示
    showClimateChart(cultivation.id);
    
    // 従来のポップアップも表示（オプション）
    // showCultivationPopup(cultivation, e.clientX, e.clientY);
  });

  barGroup.appendChild(barBg);

  // バーのラベル（作物名）- 常に表示
  const labelText = cultivation.crop_name;
  
  barGroup.appendChild(createSVGElement('text', {
    x: barX + (barWidth / 2),
    y: barY + (config.barHeight / 2) + 5,
    class: 'bar-label',
    'text-anchor': 'middle',
    'font-size': '12',
    'font-weight': '600',
    fill: '#1F2937',
    style: 'pointer-events: none;'
  }, labelText));

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

