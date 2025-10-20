// app/javascript/cultivation_results.js
// 作付け計画完成画面のインタラクション

document.addEventListener('DOMContentLoaded', () => {
  initCultivationResults();
});

function initCultivationResults() {
  const detailPanel = document.getElementById('detailPanel');
  if (!detailPanel) return;

  // ガントチャート行のクリックイベント
  initGanttRowClick();
  
  // 詳細パネルの閉じるボタン
  initPanelClose();
  
  // タブ切り替え
  initTabSwitching();
  
  // オーバーレイクリックで閉じる
  initOverlayClick();
}

// ガントチャート行クリック
function initGanttRowClick() {
  const ganttRows = document.querySelectorAll('.gantt-row');
  
  ganttRows.forEach(row => {
    row.addEventListener('click', async (e) => {
      // 既存の選択を解除
      document.querySelectorAll('.gantt-row.selected').forEach(r => {
        r.classList.remove('selected');
      });
      
      // 選択状態を追加
      row.classList.add('selected');
      
      // 詳細パネルを表示
      const fieldCultivationId = row.dataset.fieldCultivationId;
      const fieldName = row.dataset.fieldName;
      const cropName = row.dataset.cropName;
      
      await showDetailPanel(fieldCultivationId, fieldName, cropName);
    });
  });
}

// 詳細パネルを表示
async function showDetailPanel(fieldCultivationId, fieldName, cropName) {
  const detailPanel = document.getElementById('detailPanel');
  const panelTitle = document.getElementById('panelTitle');
  const panelLoading = document.getElementById('panelLoading');
  const panelContent = document.getElementById('panelContent');
  
  // パネルを表示
  detailPanel.style.display = 'block';
  setTimeout(() => {
    detailPanel.classList.add('active');
  }, 10);
  
  // タイトルを設定
  panelTitle.innerHTML = `
    <span class="panel-title-icon">🏞️</span>
    <span class="panel-title-text">${fieldName} - ${cropName}</span>
  `;
  
  // ローディング表示
  panelLoading.style.display = 'flex';
  document.querySelectorAll('.detail-tab-content').forEach(tab => {
    tab.style.display = 'none';
  });
  
  try {
    // APIからデータ取得
    const response = await fetch(`/api/v1/public_plans/field_cultivations/${fieldCultivationId}`);
    if (!response.ok) throw new Error(getI18nMessage('jsCultivationLoadError', 'Failed to retrieve data'));
    
    const data = await response.json();
    
    // ローディングを非表示
    panelLoading.style.display = 'none';
    
    // データを各タブに注入
    populateInfoTab(data);
    populateTemperatureTab(data);
    populateStagesTab(data);
    
    // 最初のタブを表示
    document.getElementById('tab-info-content').style.display = 'block';
    
  } catch (error) {
    console.error('Error loading detail data:', error);
    panelLoading.innerHTML = `
      <div style="text-align: center; color: #e53e3e;">
        <p>${getI18nMessage('jsCultivationDataError', 'Failed to load data')}</p>
        <p style="font-size: 0.9rem; margin-top: 0.5rem;">${error.message}</p>
      </div>
    `;
  }
}

// 基本情報タブにデータを注入
function populateInfoTab(data) {
  const infoTab = document.getElementById('tab-info-content');
  
  // 各フィールドに値を設定
  setFieldValue(infoTab, 'field_name', data.field_name);
  setFieldValue(infoTab, 'crop_name', data.crop_name);
  setFieldValue(infoTab, 'area', `${formatNumber(data.area)}㎡`);
  setFieldValue(infoTab, 'start_date', formatDate(data.start_date));
  setFieldValue(infoTab, 'completion_date', formatDate(data.completion_date));
  setFieldValue(infoTab, 'cultivation_days', `${data.cultivation_days}日`);
  setFieldValue(infoTab, 'gdd', `${formatNumber(data.gdd)}℃日`);
  setFieldValue(infoTab, 'estimated_cost', `¥${formatNumber(data.estimated_cost)}`);
  
  // ステージタイムラインを生成
  if (data.stages && data.stages.length > 0) {
    const timeline = infoTab.querySelector('[data-field="stages_timeline"]');
    timeline.innerHTML = data.stages.map(stage => `
      <div class="stage-timeline-item">
        <div class="stage-timeline-bar" style="background: ${getStageColor(stage.name)};">
          <span class="stage-timeline-icon">${getStageIcon(stage.name)}</span>
          <span class="stage-timeline-name">${stage.name}</span>
        </div>
        <div class="stage-timeline-info">
          <span>${stage.start_date} - ${stage.end_date}</span>
          <span>${stage.days}日</span>
          <span>${formatNumber(stage.gdd)}℃日</span>
        </div>
      </div>
    `).join('');
  }
}

// 気温分析タブにデータを注入
function populateTemperatureTab(data) {
  const tempTab = document.getElementById('tab-temperature-content');
  
  // 統計情報を設定
  if (data.temperature_stats) {
    const stats = data.temperature_stats;
    setFieldValue(tempTab, 'optimal_days', 
      `${stats.optimal_days}日 / ${stats.total_days}日 (${stats.optimal_percentage}%)`);
    setFieldValue(tempTab, 'high_temp_days', `${stats.high_temp_days}日`);
    setFieldValue(tempTab, 'low_temp_days', `${stats.low_temp_days}日`);
  }
  
  // GDD情報を設定
  if (data.gdd_info) {
    const gdd = data.gdd_info;
    setFieldValue(tempTab, 'target_gdd', `${formatNumber(gdd.target)}℃日`);
    setFieldValue(tempTab, 'actual_gdd', 
      `${formatNumber(gdd.actual)}℃日 (${gdd.percentage >= 0 ? '+' : ''}${gdd.percentage}%)`);
    setFieldValue(tempTab, 'gdd_achievement_date', formatDate(gdd.achievement_date));
  }
  
  // グラフを描画
  if (data.weather_data) {
    drawTemperatureChart(data.weather_data, data.optimal_temperature_range);
    drawGddChart(data.gdd_data);
  }
}

// ステージタブにデータを注入
function populateStagesTab(data) {
  const stagesTab = document.getElementById('tab-stages-content');
  const stagesList = stagesTab.querySelector('[data-field="stages_list"]');
  
  if (data.stages && data.stages.length > 0) {
    stagesList.innerHTML = data.stages.map(stage => `
      <div class="stage-card">
        <div class="stage-card-header">
          <span class="stage-icon">${getStageIcon(stage.name)}</span>
          <span class="stage-name">${stage.name}</span>
          <span class="stage-period">${stage.start_date} - ${stage.end_date} (${stage.days}日)</span>
        </div>
        <div class="stage-card-body">
          <div class="stage-stat">
            <span class="stat-label">積算温度:</span>
            <span class="stat-value">${formatNumber(stage.gdd_actual)}℃日 / ${formatNumber(stage.gdd_required)}℃日 ${stage.gdd_achieved ? '✓' : ''}</span>
          </div>
          <div class="stage-stat">
            <span class="stat-label">平均気温:</span>
            <span class="stat-value">${stage.avg_temp}℃</span>
          </div>
          <div class="stage-stat">
            <span class="stat-label">最適範囲:</span>
            <span class="stat-value">${stage.optimal_temp_min}-${stage.optimal_temp_max}℃</span>
          </div>
          <div class="stage-stat">
            <span class="stat-label">リスク:</span>
            <span class="stat-value ${stage.risks.length === 0 ? 'stat-success' : 'stat-warning'}">
              ${stage.risks.length === 0 ? getI18nMessage('jsCultivationNoRisks', 'None ✓') : stage.risks.join(', ')}
            </span>
          </div>
        </div>
      </div>
    `).join('');
  }
}

// 気温グラフを描画
function drawTemperatureChart(weatherData, optimalRange) {
  const ctx = document.getElementById('temperatureChart');
  if (!ctx) return;
  
  // 既存のチャートを破棄
  if (window.temperatureChartInstance) {
    window.temperatureChartInstance.destroy();
  }
  
  // i18n翻訳を取得
  const labels_i18n = {
    tempMax: getI18nMessage('jsCultivationTempMaxLabel', 'Max Temperature'),
    tempMean: getI18nMessage('jsCultivationTempMeanLabel', 'Mean Temperature'),
    tempMin: getI18nMessage('jsCultivationTempMinLabel', 'Min Temperature'),
    optimalRange: getI18nMessage('jsCultivationOptimalRangeLabel', 'Optimal Temperature Range'),
    dateAxis: getI18nMessage('jsCultivationDateLabel', 'Date'),
    tempAxis: getI18nMessage('jsCultivationTempAxisLabel', 'Temperature (℃)')
  };
  
  const dates = weatherData.map(d => d.date);
  const tempMax = weatherData.map(d => d.temperature_max);
  const tempMin = weatherData.map(d => d.temperature_min);
  const tempMean = weatherData.map(d => d.temperature_mean);
  
  window.temperatureChartInstance = new Chart(ctx, {
    type: 'line',
    data: {
      labels: dates,
      datasets: [
        {
          label: labels_i18n.tempMax,
          data: tempMax,
          borderColor: '#f56565',
          backgroundColor: 'rgba(245, 101, 101, 0.1)',
          borderWidth: 2,
          pointRadius: 2
        },
        {
          label: labels_i18n.tempMean,
          data: tempMean,
          borderColor: '#48bb78',
          backgroundColor: 'rgba(72, 187, 120, 0.1)',
          borderWidth: 2,
          pointRadius: 2
        },
        {
          label: labels_i18n.tempMin,
          data: tempMin,
          borderColor: '#4299e1',
          backgroundColor: 'rgba(66, 153, 225, 0.1)',
          borderWidth: 2,
          pointRadius: 2
        }
      ]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: {
          position: 'top',
        },
        tooltip: {
          mode: 'index',
          intersect: false,
        },
        annotation: optimalRange ? {
          annotations: {
            optimalBox: {
              type: 'box',
              yMin: optimalRange.min,
              yMax: optimalRange.max,
              backgroundColor: 'rgba(72, 187, 120, 0.1)',
              borderColor: 'rgba(72, 187, 120, 0.3)',
              borderWidth: 1,
              label: {
                content: labels_i18n.optimalRange,
                enabled: true,
                position: 'start'
              }
            }
          }
        } : {}
      },
      scales: {
        x: {
          display: true,
          title: {
            display: true,
            text: labels_i18n.dateAxis
          }
        },
        y: {
          display: true,
          title: {
            display: true,
            text: labels_i18n.tempAxis
          }
        }
      }
    }
  });
}

// GDDグラフを描画
function drawGddChart(gddData) {
  const ctx = document.getElementById('gddChart');
  if (!ctx) return;
  
  // 既存のチャートを破棄
  if (window.gddChartInstance) {
    window.gddChartInstance.destroy();
  }
  
  // i18n翻訳を取得
  const labels_i18n = {
    gddLabel: getI18nMessage('jsCultivationGddLabel', 'Growing Degree Days'),
    gddAxis: getI18nMessage('jsCultivationGddAxisLabel', 'GDD (℃·day)'),
    dateAxis: getI18nMessage('jsCultivationDateLabel', 'Date')
  };
  
  const dates = gddData.map(d => d.date);
  const accumulatedGdd = gddData.map(d => d.accumulated_gdd);
  const targetGdd = gddData.length > 0 ? gddData[0].target_gdd : 0;
  
  window.gddChartInstance = new Chart(ctx, {
    type: 'line',
    data: {
      labels: dates,
      datasets: [
        {
          label: labels_i18n.gddLabel,
          data: accumulatedGdd,
          borderColor: '#667eea',
          backgroundColor: 'rgba(102, 126, 234, 0.2)',
          borderWidth: 2,
          fill: true,
          pointRadius: 2
        }
      ]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: {
          position: 'top',
        },
        tooltip: {
          mode: 'index',
          intersect: false,
        },
        annotation: targetGdd ? {
          annotations: {
            targetLine: {
              type: 'line',
              yMin: targetGdd,
              yMax: targetGdd,
              borderColor: '#e53e3e',
              borderWidth: 2,
              borderDash: [5, 5],
              label: {
                content: getI18nTemplate('jsCultivationGddTargetLabel', {target: targetGdd}, `Target: ${targetGdd}℃·day`),
                enabled: true,
                position: 'end'
              }
            }
          }
        } : {}
      },
      scales: {
        x: {
          display: true,
          title: {
            display: true,
            text: labels_i18n.dateAxis
          }
        },
        y: {
          display: true,
          title: {
            display: true,
            text: labels_i18n.gddAxis
          }
        }
      }
    }
  });
}

// 詳細パネルを閉じる
function initPanelClose() {
  const closeBtn = document.getElementById('closePanelBtn');
  if (!closeBtn) return;
  
  closeBtn.addEventListener('click', () => {
    hideDetailPanel();
  });
}

// オーバーレイクリックで閉じる
function initOverlayClick() {
  const overlay = document.getElementById('panelOverlay');
  if (!overlay) return;
  
  overlay.addEventListener('click', () => {
    hideDetailPanel();
  });
}

function hideDetailPanel() {
  const detailPanel = document.getElementById('detailPanel');
  detailPanel.classList.remove('active');
  
  setTimeout(() => {
    detailPanel.style.display = 'none';
  }, 300);
  
  // 選択状態を解除
  document.querySelectorAll('.gantt-row.selected').forEach(r => {
    r.classList.remove('selected');
  });
}

// タブ切り替え
function initTabSwitching() {
  const tabButtons = document.querySelectorAll('.detail-tab-btn');
  
  tabButtons.forEach(btn => {
    btn.addEventListener('click', () => {
      const tabName = btn.dataset.tab;
      
      // ボタンのアクティブ状態を切り替え
      tabButtons.forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      
      // タブコンテンツを切り替え
      document.querySelectorAll('.detail-tab-content').forEach(tab => {
        tab.style.display = 'none';
      });
      
      const targetTab = document.getElementById(`tab-${tabName}-content`);
      if (targetTab) {
        targetTab.style.display = 'block';
      }
    });
  });
}

// ヘルパー関数
function setFieldValue(container, fieldName, value) {
  const element = container.querySelector(`[data-field="${fieldName}"]`);
  if (element) {
    element.textContent = value;
  }
}

function formatNumber(num) {
  if (num === null || num === undefined) return '-';
  return Math.round(num).toLocaleString('ja-JP');
}

function formatDate(dateString) {
  if (!dateString) return '-';
  const date = new Date(dateString);
  return date.toLocaleDateString('ja-JP', { 
    year: 'numeric', 
    month: 'long', 
    day: 'numeric' 
  });
}

function getStageColor(stageName) {
  const colors = {
    '発芽': '#90EE90',
    '成長': '#32CD32',
    '開花': '#FFB6C1',
    '結実': '#FF6347',
    '収穫': '#FFD700'
  };
  return colors[stageName] || '#CCCCCC';
}

function getStageIcon(stageName) {
  const icons = {
    '発芽': '🌱',
    '成長': '🌿',
    '開花': '🌸',
    '結実': '🍅',
    '収穫': '📦'
  };
  return icons[stageName] || '•';
}

