import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    try {
      const chartContainer = document.getElementById('gantt-chart-container');
      if (!chartContainer) return;

      const planId = chartContainer.dataset.cultivationPlanId;
      const dataUrl = chartContainer.dataset.dataUrl;
      if (!planId || !dataUrl) {
        console.error('[plans-show] Missing plan ID or data URL');
        this.showError(chartContainer, 'データの読み込みに必要な情報が不足しています');
        return;
      }

      fetch(dataUrl)
        .then((response) => {
          if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
          }
          return response.json();
        })
        .then((data) => {
          if (!data.success) {
            throw new Error(data.message || '読み込みに失敗しました');
          }
          const planData = data.data;
          if (typeof window.prepareGanttData === 'function' && typeof window.setGanttDataAttributes === 'function') {
            const ganttData = window.prepareGanttData(planData);
            window.setGanttDataAttributes(chartContainer, ganttData);
          }
          // 二重初期化ガード解除 → 初期化
          if (chartContainer.dataset.ganttInitialized === 'true') {
            delete chartContainer.dataset.ganttInitialized;
          }
          if (typeof window.initCustomGanttChart === 'function') {
            window.initCustomGanttChart();
          } else {
            throw new Error('ガントチャート機能が読み込まれていません');
          }
        })
        .catch((err) => {
          console.error('[plans-show] load error', err);
          this.showError(chartContainer, `データの読み込みに失敗しました: ${err.message}`);
        });
    } catch (e) {
      console.error('[plans-show] connect error', e);
    }
  }

  disconnect() {
    try {
      if (typeof window.cleanupGanttChart === 'function') {
        window.cleanupGanttChart();
      }
    } catch (e) {
      console.error('[plans-show] disconnect error', e);
    }
  }

  showError(container, message) {
    if (!container) return;
    container.innerHTML = `
      <div class="gantt-error-container">
        <div class="gantt-error-icon">⚠️</div>
        <p class="gantt-error-message">${message}</p>
      </div>
    `;
  }
}
