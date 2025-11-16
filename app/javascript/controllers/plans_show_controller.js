import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    // plans_show.js 相当の初期化を最小限にラップし、既存の custom_gantt_chart.js に委譲
    try {
      const chartContainer = document.getElementById('gantt-chart-container');
      if (!chartContainer) return;
      // 既存の二重初期化ガードを尊重
      if (typeof window.initCustomGanttChart === 'function') {
        // 既存初期化済みフラグがある場合は解除して再初期化可能にする
        if (chartContainer.dataset.ganttInitialized === 'true') {
          delete chartContainer.dataset.ganttInitialized;
        }
        window.initCustomGanttChart();
      }
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
}


