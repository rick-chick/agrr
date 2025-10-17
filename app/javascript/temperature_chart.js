import { Chart, registerables } from 'chart.js';

// Chart.jsのコンポーネントを登録
Chart.register(...registerables);

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
        this.showError('選択した期間のデータがありません。');
        return;
      }

      console.log(`Loaded ${result.data.length} weather data points`);
      this.renderChart(result.data, false);
    } catch (error) {
      console.error('Error loading chart data:', error);
      this.showError('データの読み込みに失敗しました。');
    }
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

      if (!result.success) {
        console.error('Failed to load prediction data:', result.message);
        this.showError(result.message);
        return;
      }

      if (!result.data || result.data.length === 0) {
        console.warn('No prediction data available');
        this.showError('予測データがありません。');
        return;
      }

      console.log(`Loaded ${result.data.length} prediction data points`);
      this.renderChart(result.data, true);
    } catch (error) {
      console.error('Error loading prediction data:', error);
      this.showError('予測データの読み込みに失敗しました。');
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

    // データの準備
    const labels = data.map(d => d.date);
    const tempMax = data.map(d => d.temperature_max);
    const tempMin = data.map(d => d.temperature_min);
    const tempMean = data.map(d => d.temperature_mean);

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
            pointBackgroundColor: 'rgb(255, 99, 132)'
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
            pointBackgroundColor: 'rgb(75, 192, 192)'
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
            pointBackgroundColor: 'rgb(54, 162, 235)'
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
            callbacks: {
              afterLabel: function(context) {
                return isPrediction ? '（予測値）' : '';
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
              text: '温度 (°C)'
            }
          }
        },
        interaction: {
          mode: 'nearest',
          axis: 'x',
          intersect: false
        }
      }
    });
  }

  showError(message) {
    const canvas = document.getElementById('temperatureChart');
    if (canvas) {
      const container = canvas.parentElement;
      container.innerHTML = `<p class="error-message">${message}</p>`;
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

