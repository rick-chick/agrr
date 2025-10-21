import { Chart, registerables } from 'chart.js';
import CableSubscriptionManager from './cable_subscription';

// Chart.jsのコンポーネントを登録
Chart.register(...registerables);

// i18nヘルパー関数
function getI18nMessage(key, defaultMessage) {
  const canvas = document.getElementById('temperatureChart');
  if (!canvas || !canvas.dataset) return defaultMessage;
  return canvas.dataset[key] || defaultMessage;
}

// 温度チャートの初期化と管理
class TemperatureChart {
  constructor() {
    this.chart = null;
    this.farmId = null;
    this.isInitialized = false;
  }

  setupChart() {
    const canvas = document.getElementById('temperatureChart');
    if (!canvas) return;

    // 既存のチャートを破棄
    if (this.chart) {
      this.chart.destroy();
      this.chart = null;
    }

    // data属性から農場IDを取得（より確実）
    this.farmId = canvas.dataset.farmId;
    
    // ActionCableの購読を設定
    if (this.farmId) {
      this.subscribeToPredictionChannel();
    }
    
    if (!this.farmId) {
      // フォールバック: URLから取得
      const pathParts = window.location.pathname.split('/');
      const farmIndex = pathParts.indexOf('farms');
      if (farmIndex !== -1 && pathParts[farmIndex + 1]) {
        const pathId = pathParts[farmIndex + 1];
        // 数値のみを抽出（"farms_123"のような場合も対応）
        const numericId = pathId.match(/\d+/);
        this.farmId = numericId ? numericId[0] : pathId;
      }
    }
    
    if (!this.farmId) {
      console.error('Farm ID not found');
      return;
    }
    
    console.log('Chart initialized for Farm ID:', this.farmId);

    // 期間選択のイベントリスナーを設定（重複を防ぐため、古いリスナーを削除）
    const periodSelect = document.getElementById('chart-period');
    if (periodSelect) {
      // 既存のイベントリスナーを削除するため、新しい要素に置き換える
      const newPeriodSelect = periodSelect.cloneNode(true);
      periodSelect.parentNode.replaceChild(newPeriodSelect, periodSelect);
      
      newPeriodSelect.addEventListener('change', (e) => {
        const value = e.target.value;
        if (value === 'next_365') {
          this.loadPredictionData();
        } else {
          this.loadChartData(parseInt(value));
        }
      });
    }

    // 初期データを読み込み
    const currentSelect = document.getElementById('chart-period');
    const initialPeriod = currentSelect ? currentSelect.value : '365';
    if (initialPeriod === 'next_365') {
      this.loadPredictionData();
    } else {
      this.loadChartData(parseInt(initialPeriod));
    }
  }

  async loadChartData(days) {
    if (!this.farmId) {
      console.error('Farm ID is not set');
      return;
    }

    // daysパラメータのバリデーション
    if (isNaN(days) || days <= 0) {
      console.error('Invalid days parameter:', days);
      return;
    }

    try {
      const endDate = new Date();
      const startDate = new Date();
      startDate.setDate(startDate.getDate() - days);

      const startDateStr = startDate.toISOString().split('T')[0];
      const endDateStr = endDate.toISOString().split('T')[0];

      const url = `/farms/${this.farmId}/weather_data?start_date=${startDateStr}&end_date=${endDateStr}`;
      const response = await fetch(url);
      const result = await response.json();

      if (!result.success) {
        console.error('Failed to load weather data:', result.message);
        console.error('URL:', url);
        console.error('Response:', result);
        this.showError(result.message);
        return;
      }

      if (!result.data || result.data.length === 0) {
        console.warn('No weather data available for the selected period');
        this.showError(getI18nMessage('noData', 'No data available for the selected period.'));
        return;
      }

      console.log(`Loaded ${result.data.length} weather data points`);
      this.renderChart(result.data, false);
    } catch (error) {
      console.error('Error loading chart data:', error);
      this.showError(getI18nMessage('loadFailed', 'Failed to load data.'));
    }
  }

  subscribeToPredictionChannel() {
    CableSubscriptionManager.subscribeToPrediction(this.farmId, {
      onConnected: () => {
        console.log('🔌 Prediction channel connected');
      },
      
      onReceived: (data) => {
        console.log('📬 Prediction channel received:', data);
        if (data.type === 'prediction_completed' || data.type === 'prediction_ready') {
          console.log('✅ Prediction completed, reloading data...');
          // 予測が完了したので、データを再読み込み
          this.loadPredictionData();
        }
      },
      
      onDisconnected: () => {
        console.log('❌ Prediction channel disconnected');
      }
    });
  }

  async loadPredictionData() {
    if (!this.farmId) {
      console.error('Farm ID is not set');
      return;
    }

    try {
      console.log('Loading prediction data...');
      const url = `/farms/${this.farmId}/weather_data?predict=true`;
      const response = await fetch(url);
      const result = await response.json();

      // バックグラウンド処理中の場合
      if (result.status === 'processing') {
        console.log('Prediction is being processed in background...');
        
        // 既存のチャートを破棄
        if (this.chart) {
          this.chart.destroy();
          this.chart = null;
        }
        
        this.showError(result.message || getI18nMessage('predictionProcessing', 'Prediction is being processed. Please wait...'));
        // ActionCableで完了通知を待つ（ポーリング不要）
        return;
      }

      if (!result.success) {
        console.error('Failed to load prediction data:', result.message);
        
        // 既存のチャートを破棄
        if (this.chart) {
          this.chart.destroy();
          this.chart = null;
        }
        
        this.showError(result.message);
        return;
      }

      if (!result.data || result.data.length === 0) {
        console.warn('No prediction data available');
        
        // 既存のチャートを破棄
        if (this.chart) {
          this.chart.destroy();
          this.chart = null;
        }
        
        this.showError(getI18nMessage('noPredictionData', 'No prediction data available.'));
        return;
      }

      console.log(`Loaded ${result.data.length} prediction data points`);
      this.renderChart(result.data, true);
    } catch (error) {
      console.error('Error loading prediction data:', error);
      
      // 既存のチャートを破棄
      if (this.chart) {
        this.chart.destroy();
        this.chart = null;
      }
      
      this.showError(getI18nMessage('predictionLoadFailed', 'Failed to load prediction data.'));
    }
  }

  renderChart(data, isPrediction = false) {
    const canvas = document.getElementById('temperatureChart');
    if (!canvas) return;

    const ctx = canvas.getContext('2d');

    // 既存のチャートがあれば破棄
    if (this.chart) {
      this.chart.destroy();
    }

    // データの準備（null値を除外）
    const validData = data.filter(d => 
      d.date && 
      d.temperature_max !== null && d.temperature_max !== undefined &&
      d.temperature_min !== null && d.temperature_min !== undefined
    );
    
    // 有効なデータがない場合はエラーメッセージを表示
    if (validData.length === 0) {
      console.warn('No valid temperature data to display');
      this.showError(getI18nMessage('noValidData', 'No valid data available for chart display.'));
      return;
    }
    
    const labels = validData.map(d => d.date);
    const tempMax = validData.map(d => d.temperature_max);
    const tempMin = validData.map(d => d.temperature_min);
    const tempMean = validData.map(d => d.temperature_mean !== null && d.temperature_mean !== undefined ? d.temperature_mean : (d.temperature_max + d.temperature_min) / 2);

    // 予測データの場合はスタイルを変更
    const borderDash = isPrediction ? [5, 5] : [];
    const pointStyle = isPrediction ? 'circle' : false;
    const pointRadius = isPrediction ? 2 : 0;
    const chartCanvas = document.getElementById('temperatureChart');
    const titleText = isPrediction ? 
      (chartCanvas?.dataset.chartTitlePrediction || '温度推移（予測）') : 
      (chartCanvas?.dataset.chartTitle || '温度推移');
    
    // ラベルをdata属性から取得
    const labels_i18n = {
      tempMax: chartCanvas?.dataset.tempMaxLabel || '最高気温 (°C)',
      tempMean: chartCanvas?.dataset.tempMeanLabel || '平均気温 (°C)',
      tempMin: chartCanvas?.dataset.tempMinLabel || '最低気温 (°C)',
      dateLabel: chartCanvas?.dataset.dateLabel || '日付'
    };

    // チャートの作成
    this.chart = new Chart(ctx, {
      type: 'line',
      data: {
        labels: labels,
        datasets: [
          {
            label: labels_i18n.tempMax,
            data: tempMax,
            borderColor: 'rgb(255, 99, 132)',
            backgroundColor: 'rgba(255, 99, 132, 0.1)',
            tension: 0.3,
            fill: false,
            borderDash: borderDash,
            pointStyle: pointStyle,
            pointRadius: pointRadius,
            pointBackgroundColor: 'rgb(255, 99, 132)',
            spanGaps: true  // null値をスキップ
          },
          {
            label: labels_i18n.tempMean,
            data: tempMean,
            borderColor: 'rgb(75, 192, 192)',
            backgroundColor: 'rgba(75, 192, 192, 0.1)',
            tension: 0.3,
            fill: false,
            borderDash: borderDash,
            pointStyle: pointStyle,
            pointRadius: pointRadius,
            pointBackgroundColor: 'rgb(75, 192, 192)',
            spanGaps: true  // null値をスキップ
          },
          {
            label: labels_i18n.tempMin,
            data: tempMin,
            borderColor: 'rgb(54, 162, 235)',
            backgroundColor: 'rgba(54, 162, 235, 0.1)',
            tension: 0.3,
            fill: false,
            borderDash: borderDash,
            pointStyle: pointStyle,
            pointRadius: pointRadius,
            pointBackgroundColor: 'rgb(54, 162, 235)',
            spanGaps: true  // null値をスキップ
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: true,
        aspectRatio: 2,
        plugins: {
          legend: {
            position: 'top',
          },
          title: {
            display: true,
            text: titleText
          },
          tooltip: {
            mode: 'index',
            intersect: false,
            filter: function(tooltipItem) {
              // tooltipItem、element、parsedの存在チェック
              if (!tooltipItem) return false;
              if (!tooltipItem.element) return false;
              if (!tooltipItem.parsed) return false;
              
              // null値を持つデータポイントをtooltipから除外
              const y = tooltipItem.parsed.y;
              return y !== null && 
                     y !== undefined &&
                     !isNaN(y);
            },
            callbacks: {
              afterLabel: function(context) {
                return isPrediction ? getI18nMessage('predictedValue', '(Predicted)') : '';
              }
            }
          }
        },
        scales: {
          x: {
            display: true,
            title: {
              display: true,
              text: labels_i18n.dateLabel
            },
            ticks: {
              maxTicksLimit: 15,
              maxRotation: 45,
              minRotation: 0
            }
          },
          y: {
            display: true,
            title: {
              display: true,
              text: chartCanvas?.dataset.temperatureLabel || '温度 (°C)'
            }
          }
        },
        interaction: {
          mode: 'nearest',
          axis: 'x',
          intersect: false
        },
        elements: {
          point: {
            // ホバー時のポイントのヒットボックスを制御
            hitRadius: 10,
            hoverRadius: 5
          }
        },
        // nullやundefinedの値を持つデータポイントをスキップ
        parsing: {
          xAxisKey: 'date',
          yAxisKey: 'value'
        }
      }
    });
  }

  showError(message) {
    const canvas = document.getElementById('temperatureChart');
    if (canvas) {
      const container = canvas.parentElement;
      // キャンバスを削除してエラーメッセージのみ表示
      container.innerHTML = `<p class="error-message">${message}</p>`;
      
      // 新しいキャンバスを作成（次回の描画用）
      const newCanvas = document.createElement('canvas');
      newCanvas.id = 'temperatureChart';
      newCanvas.dataset.farmId = this.farmId;
      // data属性をコピー
      if (canvas.dataset) {
        Object.keys(canvas.dataset).forEach(key => {
          newCanvas.dataset[key] = canvas.dataset[key];
        });
      }
      container.appendChild(newCanvas);
    }
  }
}

// シングルトンインスタンス
let chartInstance = null;

// Turboナビゲーション対応の初期化
function initializeChart() {
  if (!chartInstance) {
    chartInstance = new TemperatureChart();
  }
  chartInstance.setupChart();
}

// ページ読み込み時とTurboナビゲーション後に初期化
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initializeChart);
} else {
  initializeChart();
}

document.addEventListener('turbo:load', initializeChart);
document.addEventListener('turbo:render', initializeChart);

