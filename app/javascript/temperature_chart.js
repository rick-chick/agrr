import { Chart, registerables } from 'chart.js';

// Chart.jsのコンポーネントを登録
Chart.register(...registerables);

// 温度チャートの初期化と管理
class TemperatureChart {
  constructor() {
    this.chart = null;
    this.farmId = null;
    this.init();
  }

  init() {
    // ページ読み込み時にチャートを初期化
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', () => this.setupChart());
    } else {
      this.setupChart();
    }

    // Turboナビゲーション後の初期化
    document.addEventListener('turbo:load', () => this.setupChart());
  }

  setupChart() {
    const canvas = document.getElementById('temperatureChart');
    if (!canvas) return;

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

    // 期間選択のイベントリスナーを設定
    const periodSelect = document.getElementById('chart-period');
    if (periodSelect) {
      periodSelect.addEventListener('change', (e) => {
        this.loadChartData(parseInt(e.target.value));
      });
    }

    // 初期データを読み込み
    const initialPeriod = periodSelect ? parseInt(periodSelect.value) : 365;
    this.loadChartData(initialPeriod);
  }

  async loadChartData(days) {
    if (!this.farmId) {
      console.error('Farm ID is not set');
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
      this.renderChart(result.data);
    } catch (error) {
      console.error('Error loading chart data:', error);
      this.showError('データの読み込みに失敗しました。');
    }
  }

  renderChart(data) {
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

    // チャートの作成
    this.chart = new Chart(ctx, {
      type: 'line',
      data: {
        labels: labels,
        datasets: [
          {
            label: '最高気温 (°C)',
            data: tempMax,
            borderColor: 'rgb(255, 99, 132)',
            backgroundColor: 'rgba(255, 99, 132, 0.1)',
            tension: 0.3,
            fill: false
          },
          {
            label: '平均気温 (°C)',
            data: tempMean,
            borderColor: 'rgb(75, 192, 192)',
            backgroundColor: 'rgba(75, 192, 192, 0.1)',
            tension: 0.3,
            fill: false
          },
          {
            label: '最低気温 (°C)',
            data: tempMin,
            borderColor: 'rgb(54, 162, 235)',
            backgroundColor: 'rgba(54, 162, 235, 0.1)',
            tension: 0.3,
            fill: false
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
            text: '温度推移'
          },
          tooltip: {
            mode: 'index',
            intersect: false,
          }
        },
        scales: {
          x: {
            display: true,
            title: {
              display: true,
              text: '日付'
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

// アプリケーション起動時にTemperatureChartを初期化
new TemperatureChart();

