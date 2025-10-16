// app/javascript/climate_chart.js
// 作物栽培の気温・GDDチャート（ガントチャート統合版）

// Chart.jsは既にapplication.jsでグローバルに登録済み
// annotationPluginも既に登録済み

class ClimateChart {
  constructor() {
    this.temperatureChart = null;
    this.gddChart = null;
    this.currentFieldCultivationId = null;
  }

  // ラベル用に日時文字列から日付のみを抽出（yyyy-MM-dd）
  formatDateLabel(dateInput) {
    if (typeof dateInput === 'string') {
      // ISOや任意の文字列でも先頭10文字（yyyy-MM-dd）を優先
      if (dateInput.length >= 10 && /\d{4}-\d{2}-\d{2}/.test(dateInput.slice(0, 10))) {
        return dateInput.slice(0, 10);
      }
    }
    const d = new Date(dateInput);
    const yyyy = d.getFullYear();
    const mm = String(d.getMonth() + 1).padStart(2, '0');
    const dd = String(d.getDate()).padStart(2, '0');
    return `${yyyy}-${mm}-${dd}`;
  }

  /**
   * 気温・GDDチャートを表示
   * @param {number} fieldCultivationId - 栽培ID
   * @param {HTMLElement} container - チャートを表示するコンテナ
   */
  async show(fieldCultivationId, container) {
    if (!container) {
      console.error('Chart container not found');
      return;
    }

    this.currentFieldCultivationId = fieldCultivationId;

    // ローディング表示
    container.innerHTML = '<div class="climate-chart-loading">データを読み込んでいます...</div>';
    container.style.display = 'block';

    try {
      // APIからデータ取得（タイムアウトを20秒に設定）
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 20000); // 20秒でタイムアウト
      
      console.log('🔄 Fetching API data...');
      const response = await fetch(`/api/v1/public_plans/field_cultivations/${fieldCultivationId}/climate_data`, {
        signal: controller.signal
      });
      clearTimeout(timeoutId);
      
      console.log('📡 API response received:', response.status, response.statusText);
      const data = await response.json();
      console.log('📊 API data received:', data);

      if (!data.success) {
        throw new Error(data.message || 'データの取得に失敗しました');
      }

      console.log('✅ API data validation passed, rendering charts...');
      // チャート描画
      this.renderCharts(data, container);
    } catch (error) {
      console.error('Error loading climate data:', error);
      container.innerHTML = `
        <div class="climate-chart-error">
          <p>データの読み込みに失敗しました</p>
          <p class="error-details">${error.message}</p>
        </div>
      `;
    }
  }

  /**
   * チャートを非表示
   * @param {HTMLElement} container - チャートコンテナ
   */
  hide(container) {
    if (container) {
      container.style.display = 'none';
    }
    this.destroyCharts();
  }

  /**
   * チャートを破棄
   */
  destroyCharts() {
    if (this.temperatureChart) {
      this.temperatureChart.destroy();
      this.temperatureChart = null;
    }
    if (this.gddChart) {
      this.gddChart.destroy();
      this.gddChart = null;
    }
  }

  /**
   * チャートを描画
   * @param {Object} data - APIから取得したデータ
   * @param {HTMLElement} container - チャートコンテナ
   */
  renderCharts(data, container) {
    // 既存のチャートを破棄
    this.destroyCharts();

    // HTMLを構築
    container.innerHTML = `
      <div class="climate-chart-container">
        <div class="climate-chart-header">
          <div class="chart-title">
            <span class="chart-title-icon">🌡️</span>
            <span class="chart-title-text">気象データと作物成長分析</span>
            <span class="crop-badge">${data.field_cultivation.crop_name}</span>
            <span class="region-badge">${data.farm.name}</span>
          </div>
          <div class="date-range">
            ${data.field_cultivation.start_date} 〜 ${data.field_cultivation.completion_date}
          </div>
          <button class="chart-close-btn" id="closeClimateChart">×</button>
        </div>
        
        <!-- 気温チャート -->
        <div class="temperature-chart-section">
          <h4 class="chart-section-title">
            <span class="chart-label-icon">🌡️</span>
            日別気温（°C）
          </h4>
          <div class="chart-canvas-wrapper">
            <canvas id="climateTemperatureChart"></canvas>
          </div>
        </div>
        
        <!-- GDDチャート -->
        <div class="gdd-chart-section">
          <h4 class="chart-section-title">
            <span class="chart-label-icon">📈</span>
            GDD推移（日別・積算・要求）
          </h4>
          <div class="chart-canvas-wrapper">
            <canvas id="climateGddChart"></canvas>
          </div>
        </div>
        
      </div>
    `;

    // 閉じるボタンのイベント
    const closeBtn = document.getElementById('closeClimateChart');
    if (closeBtn) {
      closeBtn.addEventListener('click', () => {
        this.hide(container);
      });
    }

    // チャートを描画
    setTimeout(() => {
      this.drawTemperatureChart(data);
      this.drawGddChart(data);
    }, 100);
  }

  /**
   * 気温チャートを描画
   * @param {Object} data - APIデータ
   */
  drawTemperatureChart(data) {
    const ctx = document.getElementById('climateTemperatureChart');
    if (!ctx) {
      console.error('Temperature chart canvas not found');
      return;
    }

    console.log('🌡️ Drawing temperature chart with data:', {
      weatherDataLength: data.weather_data?.length || 0,
      stagesLength: data.stages?.length || 0,
      chartAvailable: typeof Chart !== 'undefined'
    });

    // 日付配列（表示は日付のみ）
    const dates = data.weather_data.map(d => this.formatDateLabel(d.date));
    
    // アノテーション設定
    const annotations = this.createStageAnnotations(data, dates);
    console.log('📊 Annotations created:', Object.keys(annotations));
    console.log('📊 Annotations details:', annotations);

    // 温度帯の凡例データを作成
    const temperatureZoneLegend = this.createTemperatureZoneLegend(data);

    try {
      this.temperatureChart = new Chart(ctx, {
        type: 'line',
        data: {
          labels: dates,
          datasets: [
            {
              label: '最高気温',
              data: data.weather_data.map(d => d.temperature_max),
              borderColor: '#ef4444',
              backgroundColor: 'rgba(239, 68, 68, 0.1)',
              borderWidth: 2,
              tension: 0.1
            },
            {
              label: '平均気温',
              data: data.weather_data.map(d => d.temperature_mean),
              borderColor: '#3b82f6',
              backgroundColor: 'rgba(59, 130, 246, 0.1)',
              borderWidth: 2,
              tension: 0.1
            },
            {
              label: '最低気温',
              data: data.weather_data.map(d => d.temperature_min),
              borderColor: '#06b6d4',
              backgroundColor: 'rgba(6, 182, 212, 0.1)',
              borderWidth: 2,
              tension: 0.1
            },
            // 温度帯の凡例用データセット（非表示）
            ...temperatureZoneLegend
          ]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          plugins: {
            title: {
              display: true,
              text: '日別気温推移（適正温度帯・限界温度帯表示）',
              font: { size: 16, weight: 'bold' }
            },
            legend: {
              display: true,
              position: 'top',
              labels: {
                filter: function(item, chart) {
                  // 温度帯の凡例のみ表示し、実際のデータは非表示
                  return item.text.includes('適正温度帯') || item.text.includes('限界温度帯') || 
                         item.text === '最高気温' || item.text === '平均気温' || item.text === '最低気温';
                },
                generateLabels: function(chart) {
                  const original = Chart.defaults.plugins.legend.labels.generateLabels;
                  const labels = original.call(this, chart);
                  
                  // 温度帯の凡例を追加
                  labels.push(
                    {
                      text: '🟢 適正温度帯',
                      fillStyle: 'rgba(16, 185, 129, 0.3)',
                      strokeStyle: 'rgba(16, 185, 129, 0.8)',
                      lineWidth: 2,
                      hidden: false,
                      index: labels.length
                    },
                    {
                      text: '🟠 限界温度帯（ストレス）',
                      fillStyle: 'rgba(239, 68, 68, 0.2)',
                      strokeStyle: 'rgba(239, 68, 68, 0.6)',
                      lineWidth: 2,
                      lineDash: [5, 5],
                      hidden: false,
                      index: labels.length + 1
                    }
                  );
                  
                  return labels;
                }
              }
            },
          },
          scales: {
            x: {
              title: {
                display: true,
                text: '日付'
              },
              // 月曜以外のティックを除外
              afterBuildTicks: function(scale) {
                const getLabel = (v) => scale.getLabelForValue ? scale.getLabelForValue(v) : v;
                scale.ticks = scale.ticks.filter((tick) => {
                  const label = getLabel(tick.value);
                  const d = new Date(label);
                  return d.getDay() === 1; // Monday only
                });
              },
              ticks: {
                autoSkip: false,
                minRotation: 40,
                maxRotation: 40,
                callback: function(value) {
                  // value は category scale ではインデックス
                  const label = this.getLabelForValue ? this.getLabelForValue(value) : dates[value] || value;
                  const d = new Date(label);
                  if (d.getDay() === 1) {
                    return typeof label === 'string' ? label.split('T')[0] : label;
                  }
                  return '';
                }
              }
            },
            y: {
              title: {
                display: true,
                text: '気温 (°C)'
              }
            }
          }
        },
        plugins: [{
          id: 'temperatureZones',
          afterDatasetsDraw: function(chart, args, options) {
            const ctx = chart.ctx;
            
            // アノテーションを手動で描画
            Object.values(annotations).forEach(annotation => {
              const xScale = chart.scales.x;
              const yScale = chart.scales.y;
              
              if (annotation.type === 'box') {
                const x1 = xScale.getPixelForValue(annotation.xMin);
                const x2 = xScale.getPixelForValue(annotation.xMax);
                const y1 = yScale.getPixelForValue(annotation.yMin);
                const y2 = yScale.getPixelForValue(annotation.yMax);
                
                ctx.save();
                ctx.fillStyle = annotation.backgroundColor;
                ctx.fillRect(x1, y1, x2 - x1, y2 - y1);
                
                if (annotation.borderColor) {
                  ctx.strokeStyle = annotation.borderColor;
                  ctx.lineWidth = annotation.borderWidth || 1;
                  if (annotation.borderDash) {
                    ctx.setLineDash(annotation.borderDash);
                  }
                  ctx.strokeRect(x1, y1, x2 - x1, y2 - y1);
                }
                
                // ラベルを描画
                if (annotation.label && annotation.label.display) {
                  const centerX = (x1 + x2) / 2;
                  const centerY = (y1 + y2) / 2;
                  
                  ctx.fillStyle = annotation.label.backgroundColor || 'rgba(255, 255, 255, 0.9)';
                  ctx.strokeStyle = annotation.label.borderColor || 'rgba(0, 0, 0, 0.2)';
                  ctx.lineWidth = annotation.label.borderWidth || 1;
                  
                  const text = annotation.label.content;
                  const lines = text.split('\n');
                  const lineHeight = (annotation.label.font?.size || 10) + 2;
                  const padding = annotation.label.padding || 4;
                  
                  // テキストのサイズを計算
                  ctx.font = `${annotation.label.font?.weight || 'normal'} ${annotation.label.font?.size || 10}px Arial`;
                  const textWidth = Math.max(...lines.map(line => ctx.measureText(line).width));
                  const textHeight = lines.length * lineHeight;
                  
                  // 背景ボックスを描画
                  const boxX = centerX - textWidth / 2 - padding;
                  const boxY = centerY - textHeight / 2 - padding;
                  const boxWidth = textWidth + padding * 2;
                  const boxHeight = textHeight + padding * 2;
                  
                  ctx.fillRect(boxX, boxY, boxWidth, boxHeight);
                  ctx.strokeRect(boxX, boxY, boxWidth, boxHeight);
                  
                  // テキストを描画
                  ctx.fillStyle = annotation.label.color || '#000000';
                  ctx.textAlign = 'center';
                  ctx.textBaseline = 'middle';
                  
                  lines.forEach((line, index) => {
                    const textY = centerY + (index - (lines.length - 1) / 2) * lineHeight;
                    ctx.fillText(line, centerX, textY);
                  });
                }
                
                ctx.restore();
              } else if (annotation.type === 'line') {
                const x1 = xScale.getPixelForValue(annotation.xMin);
                const x2 = xScale.getPixelForValue(annotation.xMax);
                const y = yScale.getPixelForValue(annotation.yMin);
                
                ctx.save();
                ctx.strokeStyle = annotation.borderColor;
                ctx.lineWidth = annotation.borderWidth || 1;
                if (annotation.borderDash) {
                  ctx.setLineDash(annotation.borderDash);
                }
                
                ctx.beginPath();
                ctx.moveTo(x1, y);
                ctx.lineTo(x2, y);
                ctx.stroke();
                
                // ラベルを描画
                if (annotation.label && annotation.label.display) {
                  const centerX = (x1 + x2) / 2;
                  const labelY = y + (annotation.label.position?.y === 'start' ? -15 : 15);
                  
                  ctx.fillStyle = annotation.label.backgroundColor || 'rgba(255, 255, 255, 0.9)';
                  ctx.strokeStyle = annotation.label.borderColor || 'rgba(0, 0, 0, 0.2)';
                  ctx.lineWidth = annotation.label.borderWidth || 1;
                  
                  const text = annotation.label.content;
                  const lines = text.split('\n');
                  const lineHeight = (annotation.label.font?.size || 10) + 2;
                  const padding = annotation.label.padding || 4;
                  
                  // テキストのサイズを計算
                  ctx.font = `${annotation.label.font?.weight || 'normal'} ${annotation.label.font?.size || 10}px Arial`;
                  const textWidth = Math.max(...lines.map(line => ctx.measureText(line).width));
                  const textHeight = lines.length * lineHeight;
                  
                  // 背景ボックスを描画
                  const boxX = centerX - textWidth / 2 - padding;
                  const boxY = labelY - textHeight / 2 - padding;
                  const boxWidth = textWidth + padding * 2;
                  const boxHeight = textHeight + padding * 2;
                  
                  ctx.fillRect(boxX, boxY, boxWidth, boxHeight);
                  ctx.strokeRect(boxX, boxY, boxWidth, boxHeight);
                  
                  // テキストを描画
                  ctx.fillStyle = annotation.label.color || '#000000';
                  ctx.textAlign = 'center';
                  ctx.textBaseline = 'middle';
                  
                  lines.forEach((line, index) => {
                    const textY = labelY + (index - (lines.length - 1) / 2) * lineHeight;
                    ctx.fillText(line, centerX, textY);
                  });
                }
                
                ctx.restore();
              }
            });
          }
        }]
      });
      console.log('✅ Temperature chart with annotations created successfully');
    } catch (error) {
      console.error('❌ Failed to create temperature chart:', error);
      ctx.parentElement.innerHTML = `<div class="chart-error">チャートの作成に失敗しました: ${error.message}</div>`;
    }
  }

  /**
   * GDDチャートを描画
   * @param {Object} data - APIデータ
   */
  drawGddChart(data) {
    const ctx = document.getElementById('climateGddChart');
    if (!ctx) {
      console.error('GDD chart canvas not found');
      return;
    }

    const dates = data.gdd_data.map(d => this.formatDateLabel(d.date));

    try {
      this.gddChart = new Chart(ctx, {
        type: 'bar',
        data: {
          labels: dates,
          datasets: [
            {
              label: '日別GDD',
              data: data.gdd_data.map(d => d.gdd),
              backgroundColor: 'rgba(59, 130, 246, 0.04)',
              borderColor: '#3b82f6',
              borderWidth: 1,
              yAxisID: 'y'  // 左軸
            },
            {
              label: '積算GDD',
              data: data.gdd_data.map(d => d.cumulative_gdd),
              type: 'line',
              borderColor: '#22c55e',
              backgroundColor: 'rgba(34, 197, 94, 0.1)',
              borderWidth: 3,
              tension: 0.1,
              fill: false,
              yAxisID: 'y1'  // 右軸
            },
            {
              label: '要求GDD（ステップ）',
              data: this.createRequiredGddSteps(data.stages, dates),
              type: 'line',
              borderColor: '#8b5cf6',
              backgroundColor: 'rgba(139, 92, 246, 0.1)',
              borderWidth: 2,
              tension: 0,
              fill: false,
              borderDash: [5, 5],
              yAxisID: 'y1'  // 右軸
            }
          ]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          plugins: {
            title: {
              display: true,
              text: 'GDD（積算温度）推移',
              font: { size: 16, weight: 'bold' }
            },
            legend: {
              display: false
            }
          },
          scales: {
            x: {
              title: {
                display: true,
                text: '日付'
              },
              afterBuildTicks: function(scale) {
                const getLabel = (v) => scale.getLabelForValue ? scale.getLabelForValue(v) : v;
                scale.ticks = scale.ticks.filter((tick) => {
                  const label = getLabel(tick.value);
                  const d = new Date(label);
                  return d.getDay() === 1;
                });
              },
              ticks: {
                autoSkip: false,
                minRotation: 40,
                maxRotation: 40,
                callback: function(value) {
                  const label = this.getLabelForValue ? this.getLabelForValue(value) : dates[value] || value;
                  const d = new Date(label);
                  if (d.getDay() === 1) {
                    return typeof label === 'string' ? label.split('T')[0] : label;
                  }
                  return '';
                }
              }
            },
            y: {
              type: 'linear',
              position: 'left',
              title: {
                display: true,
                text: '日別GDD'
              },
              beginAtZero: true
            },
            y1: {
              type: 'linear',
              position: 'right',
              title: {
                display: true,
                text: '積算GDD / 要求GDD'
              },
              beginAtZero: true,
              grid: {
                drawOnChartArea: false  // 右軸のグリッド線を非表示
              }
            }
          }
        }
      });
      console.log('✅ GDD chart created successfully');
    } catch (error) {
      console.error('❌ Failed to create GDD chart:', error);
      ctx.parentElement.innerHTML = `<div class="chart-error">GDDチャートの作成に失敗しました: ${error.message}</div>`;
    }
  }

  /**
   * 温度帯の凡例データを作成（非表示データセット）
   * @param {Object} data - APIデータ
   * @returns {Array} 凡例用データセット
   */
  createTemperatureZoneLegend(data) {
    // 凡例表示用の非表示データセットを返す
    return [
      {
        label: '適正温度帯',
        data: [],
        hidden: true,
        pointRadius: 0,
        pointHoverRadius: 0
      },
      {
        label: '限界温度帯（ストレス）',
        data: [],
        hidden: true,
        pointRadius: 0,
        pointHoverRadius: 0
      }
    ];
  }

  /**
   * ステージごとの温度範囲アノテーションを作成
   * @param {Object} data - APIから取得したデータ
   * @param {Array} dates - 日付配列
   * @returns {Object} アノテーション設定
   */
  createStageAnnotations(data, dates) {
    const annotations = {};
    
    console.log('🔍 createStageAnnotations called with:', {
      stagesCount: data.stages?.length || 0,
      gddDataCount: data.gdd_data?.length || 0,
      datesCount: dates?.length || 0
    });
    
    if (!data.stages || data.stages.length === 0) {
      console.log('❌ No stages data available');
      return annotations;
    }
    
    // GDDデータから各ステージの開始・終了日を特定
    const stageColors = [
      { optimal: 'rgba(16, 185, 129, 0.12)', stress: 'rgba(239, 68, 68, 0.08)' },  // 緑系
      { optimal: 'rgba(59, 130, 246, 0.12)', stress: 'rgba(239, 68, 68, 0.08)' },  // 青系
      { optimal: 'rgba(245, 158, 11, 0.12)', stress: 'rgba(239, 68, 68, 0.08)' },  // オレンジ系
      { optimal: 'rgba(168, 85, 247, 0.12)', stress: 'rgba(239, 68, 68, 0.08)' }   // 紫系
    ];
    
    data.stages.forEach((stage, index) => {
      // 累積GDDに基づいてステージ期間を特定
      const prevCumulativeGdd = index > 0 ? data.stages[index - 1].cumulative_gdd_required : 0;
      const currentCumulativeGdd = stage.cumulative_gdd_required;
      
      // このステージに該当する日付範囲を抽出（累積GDDベース）
      // 重要: 範囲の境界は inclusive にする
      let stageRecords;
      if (index === data.stages.length - 1) {
        // 最終ステージの場合は、終了まで含める
        stageRecords = data.gdd_data.filter(d => d.cumulative_gdd > prevCumulativeGdd);
      } else {
        // 中間ステージ: prevCumulativeGdd < cumulative_gdd <= currentCumulativeGdd
        stageRecords = data.gdd_data.filter(d => 
          d.cumulative_gdd > prevCumulativeGdd && d.cumulative_gdd <= currentCumulativeGdd
        );
      }
      
      console.log(`ステージ ${index + 1} (${stage.name}): GDD範囲 (${prevCumulativeGdd}, ${currentCumulativeGdd}], 日数: ${stageRecords.length}, 実際のGDD範囲: ${stageRecords[0]?.cumulative_gdd || 'N/A'} - ${stageRecords[stageRecords.length - 1]?.cumulative_gdd || 'N/A'}`);
      
      // ステージ期間が0日でも、最低限のアノテーションを表示
      if (stageRecords.length > 0) {
        const startDate = this.formatDateLabel(stageRecords[0].date);
        const endDate = this.formatDateLabel(stageRecords[stageRecords.length - 1].date);
        const startIndex = dates.indexOf(startDate);
        const endIndex = dates.indexOf(endDate);
        
        if (startIndex >= 0 && endIndex >= 0) {
          const color = stageColors[index % stageColors.length];
          
          // 適正温度範囲（色付きエリア）
          annotations[`stage_optimal_${index}`] = {
            type: 'box',
            xMin: startIndex,
            xMax: endIndex,
            yMin: stage.optimal_temperature_min,
            yMax: stage.optimal_temperature_max,
            backgroundColor: color.optimal,
            borderColor: 'rgba(16, 185, 129, 0.8)',
            borderWidth: 1,
            label: {
              content: `🟢 ${stage.name}\n適正: ${stage.optimal_temperature_min}°C - ${stage.optimal_temperature_max}°C`,
              display: true,
              position: { x: 'center', y: 'start' },
              color: '#065f46',
              font: { size: 10, weight: 'bold' },
              backgroundColor: 'rgba(255, 255, 255, 0.9)',
              padding: 4,
              borderColor: 'rgba(16, 185, 129, 0.6)',
              borderWidth: 1
            }
          };
          
          // 限界温度（点線）
          if (stage.high_stress_threshold) {
            annotations[`stage_high_stress_${index}`] = {
              type: 'line',
              xMin: startIndex,
              xMax: endIndex,
              yMin: stage.optimal_temperature_max,
              yMax: stage.optimal_temperature_max,
              borderColor: 'rgba(239, 68, 68, 0.8)',
              borderWidth: 2,
              borderDash: [5, 5],
              label: {
                content: `🟠 高温限界: ${stage.high_stress_threshold}°C`,
                display: true,
                position: { x: 'center', y: 'end' },
                color: '#dc2626',
                font: { size: 9, weight: 'bold' },
                backgroundColor: 'rgba(255, 255, 255, 0.9)',
                padding: 3,
                borderColor: 'rgba(239, 68, 68, 0.8)',
                borderWidth: 1
              }
            };
            
            // 高温限界線
            annotations[`stage_high_limit_${index}`] = {
              type: 'line',
              xMin: startIndex,
              xMax: endIndex,
              yMin: stage.high_stress_threshold,
              yMax: stage.high_stress_threshold,
              borderColor: 'rgba(239, 68, 68, 0.6)',
              borderWidth: 1,
              borderDash: [3, 3]
            };
          }
          
          if (stage.low_stress_threshold) {
            annotations[`stage_low_stress_${index}`] = {
              type: 'line',
              xMin: startIndex,
              xMax: endIndex,
              yMin: stage.optimal_temperature_min,
              yMax: stage.optimal_temperature_min,
              borderColor: 'rgba(239, 68, 68, 0.8)',
              borderWidth: 2,
              borderDash: [5, 5],
              label: {
                content: `🟠 低温限界: ${stage.low_stress_threshold}°C`,
                display: true,
                position: { x: 'center', y: 'start' },
                color: '#dc2626',
                font: { size: 9, weight: 'bold' },
                backgroundColor: 'rgba(255, 255, 255, 0.9)',
                padding: 3,
                borderColor: 'rgba(239, 68, 68, 0.8)',
                borderWidth: 1
              }
            };
            
            // 低温限界線
            annotations[`stage_low_limit_${index}`] = {
              type: 'line',
              xMin: startIndex,
              xMax: endIndex,
              yMin: stage.low_stress_threshold,
              yMax: stage.low_stress_threshold,
              borderColor: 'rgba(239, 68, 68, 0.6)',
              borderWidth: 1,
              borderDash: [3, 3]
            };
          }
        }
      } else {
        // ステージ期間が0日の場合でも、全期間にアノテーションを表示
        console.log(`⚠️ ステージ ${index + 1} (${stage.name}) の期間が0日のため、全期間にアノテーションを表示`);
        
        const startIndex = 0;
        const endIndex = dates.length - 1;
        const color = stageColors[index % stageColors.length];
        
        // 適正温度範囲（色付きエリア）
        annotations[`stage_optimal_${index}`] = {
          type: 'box',
          xMin: startIndex,
          xMax: endIndex,
          yMin: stage.optimal_temperature_min,
          yMax: stage.optimal_temperature_max,
          backgroundColor: color.optimal,
          borderColor: 'rgba(16, 185, 129, 0.6)',
          borderWidth: 1,
          label: {
            content: `🟢 ${stage.name}\n適正: ${stage.optimal_temperature_min}°C - ${stage.optimal_temperature_max}°C`,
            display: true,
            position: { x: 'center', y: 'start' },
            color: '#065f46',
            font: { size: 9, weight: 'bold' },
            backgroundColor: 'rgba(255, 255, 255, 0.85)',
            padding: 3,
            borderColor: 'rgba(16, 185, 129, 0.6)',
            borderWidth: 1
          }
        };
        
        // 限界温度（点線）
        if (stage.high_stress_threshold) {
          annotations[`stage_high_stress_${index}`] = {
            type: 'line',
            xMin: startIndex,
            xMax: endIndex,
            yMin: stage.optimal_temperature_max,
            yMax: stage.optimal_temperature_max,
            borderColor: 'rgba(239, 68, 68, 0.7)',
            borderWidth: 2,
            borderDash: [5, 5],
            label: {
              content: `🟠 高温限界: ${stage.high_stress_threshold}°C`,
              display: true,
              position: { x: 'center', y: 'end' },
              color: '#dc2626',
              font: { size: 8, weight: 'bold' },
              backgroundColor: 'rgba(255, 255, 255, 0.8)',
              padding: 2,
              borderColor: 'rgba(239, 68, 68, 0.6)',
              borderWidth: 1
            }
          };
          
          // 高温限界線
          annotations[`stage_high_limit_${index}`] = {
            type: 'line',
            xMin: startIndex,
            xMax: endIndex,
            yMin: stage.high_stress_threshold,
            yMax: stage.high_stress_threshold,
            borderColor: 'rgba(239, 68, 68, 0.5)',
            borderWidth: 1,
            borderDash: [3, 3]
          };
        }
        
        if (stage.low_stress_threshold) {
          annotations[`stage_low_stress_${index}`] = {
            type: 'line',
            xMin: startIndex,
            xMax: endIndex,
            yMin: stage.optimal_temperature_min,
            yMax: stage.optimal_temperature_min,
            borderColor: 'rgba(239, 68, 68, 0.7)',
            borderWidth: 2,
            borderDash: [5, 5],
            label: {
              content: `🟠 低温限界: ${stage.low_stress_threshold}°C`,
              display: true,
              position: { x: 'center', y: 'start' },
              color: '#dc2626',
              font: { size: 8, weight: 'bold' },
              backgroundColor: 'rgba(255, 255, 255, 0.8)',
              padding: 2,
              borderColor: 'rgba(239, 68, 68, 0.6)',
              borderWidth: 1
            }
          };
          
          // 低温限界線
          annotations[`stage_low_limit_${index}`] = {
            type: 'line',
            xMin: startIndex,
            xMax: endIndex,
            yMin: stage.low_stress_threshold,
            yMax: stage.low_stress_threshold,
            borderColor: 'rgba(239, 68, 68, 0.5)',
            borderWidth: 1,
            borderDash: [3, 3]
          };
        }
      }
    });
    
    console.log('作成されたアノテーション:', Object.keys(annotations));
    console.log('アノテーション詳細:', annotations);
    return annotations;
  }

  /**
   * 要求GDDのステップラインを作成
   * @param {Array} stages - ステージデータ
   * @param {Array} dates - 日付配列
   * @returns {Array} 要求GDDのステップデータ
   */
  createRequiredGddSteps(stages, dates) {
    const steps = new Array(dates.length).fill(null);
    
    if (!stages || stages.length === 0) {
      return steps.fill(0);
    }
    
    // 各ステージの累積GDD要求値をステップ状に配置
    stages.forEach((stage, index) => {
      const prevCumulativeGdd = index > 0 ? stages[index - 1].cumulative_gdd_required : 0;
      const currentCumulativeGdd = stage.cumulative_gdd_required;
      
      // このステージに該当する日付インデックスを計算（datesはyyyy-MM-ddなので同形式に）
      // （実際のGDDデータとステージ要求を対応させる）
      const stageStartRatio = prevCumulativeGdd / stages[stages.length - 1].cumulative_gdd_required;
      const stageEndRatio = currentCumulativeGdd / stages[stages.length - 1].cumulative_gdd_required;
      
      const startIndex = Math.floor(stageStartRatio * dates.length);
      const endIndex = index === stages.length - 1 ? dates.length - 1 : Math.floor(stageEndRatio * dates.length);
      
      // このステージの期間にわたって同じ累積GDD値を設定
      for (let i = startIndex; i <= endIndex; i++) {
        steps[i] = currentCumulativeGdd;
      }
    });
    
    // null値を前の値で埋める
    let lastValue = 0;
    for (let i = 0; i < steps.length; i++) {
      if (steps[i] === null) {
        steps[i] = lastValue;
      } else {
        lastValue = steps[i];
      }
    }
    
    console.log('📊 Required GDD steps created:', steps.slice(0, 10), '...', steps.slice(-10));
    
    return steps;
  }
}

// グローバルに公開（ガントチャートから使用）
window.ClimateChart = ClimateChart;