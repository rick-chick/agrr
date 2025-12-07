import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    try {
      // Stimulus は DOM パース中にも connect を発火させるため、
      // 既存のレガシー JS（custom_gantt_chart.js など）が読み込まれる
      // DOMContentLoaded / turbo:load まで初期化を遅延させる。
      this._initializeGanttBound = this._initializeGanttBound || this.initializeGantt.bind(this);
      
      // 既に初期化済みの場合は何もしない（重複初期化を防ぐ）
      if (this._hasInitialized) {
        return;
      }

      // リスナーが既に登録されているかチェック（重複リスナー登録を防ぐ）
      if (!this._listenersAttached) {
        // DOMContentLoaded リスナーを追加（初回ロード時用）
        if (document.readyState === "loading") {
          document.addEventListener("DOMContentLoaded", this._initializeGanttBound);
        }
        
        // turbo:load リスナーを追加（初回ロード時とTurboナビゲーション時の両方で発火）
        document.addEventListener("turbo:load", this._initializeGanttBound);
        
        this._listenersAttached = true;
      }
      
      // 注意: Turbo遷移時は document.readyState が "complete" になるが、
      // turbo:load イベントが発火するまでレガシー JS が読み込まれない可能性があるため、
      // ここでは即時初期化しない（turbo:load を待つ）
    } catch (e) {
      console.error("[plans-show] connect error", e);
    }
  }

  disconnect() {
    try {
      if (this._initializeGanttBound && this._listenersAttached) {
        document.removeEventListener("DOMContentLoaded", this._initializeGanttBound);
        document.removeEventListener("turbo:load", this._initializeGanttBound);
        this._listenersAttached = false;
      }
      if (typeof window.cleanupGanttChart === "function") {
        window.cleanupGanttChart();
      }
      
      // 再接続時に再初期化できるようにフラグをリセット
      this._hasInitialized = false;
    } catch (e) {
      console.error("[plans-show] disconnect error", e);
    }
  }

  /**
   * レガシーガントチャート用のグローバル関数が読み込まれるまで待機する。
   * 一定回数（既定では100回 ≒ 数秒相当）チェックしても読み込まれない場合はエラーにする。
   *
   * 注意:
   * - Turbo遷移時には Stimulus の connect / turbo:load が先に発火し、
   *   その後に `javascript_include_tag` で読み込まれたレガシー JS が評価されることがある。
   * - そのため、ここでポーリングして `window.initCustomGanttChart` の定義を待つ。
   */
  waitForGanttScripts({ maxAttempts = 40, intervalMs = 25 } = {}) {
    return new Promise((resolve, reject) => {
      const check = (attempt = 0) => {
        if (
          typeof window.prepareGanttData === "function" &&
          typeof window.setGanttDataAttributes === "function" &&
          typeof window.initCustomGanttChart === "function"
        ) {
          resolve();
          return;
        }

        if (attempt >= maxAttempts) {
          const ganttNotLoaded =
            typeof getI18nMessage === "function"
              ? getI18nMessage(
                  "plansGanttNotLoaded",
                  "ガントチャート機能が読み込まれていません（スクリプトの読み込みに失敗した可能性があります）"
                )
              : "ガントチャート機能が読み込まれていません（スクリプトの読み込みに失敗した可能性があります）";

          reject(new Error(ganttNotLoaded));
          return;
        }

        setTimeout(() => check(attempt + 1), intervalMs);
      };

      check(0);
    });
  }

  initializeGantt() {
    if (this._hasInitialized) return;

    // 初期化を試みる前にフラグを設定して、重複実行を防ぐ
    // これにより、DOMContentLoaded と turbo:load が連続で発火しても
    // 最初の1回のみが実行される
    this._hasInitialized = true;

    try {
      const chartContainer = document.getElementById("gantt-chart-container");
      if (!chartContainer) {
        // コンテナがない場合は初期化をリセットして再試行可能にする
        this._hasInitialized = false;
        return;
      }

      const planId = chartContainer.dataset.cultivationPlanId;
      const dataUrl = chartContainer.dataset.dataUrl;
      if (!planId || !dataUrl) {
        console.error("[plans-show] Missing plan ID or data URL");
        const missing = typeof getI18nMessage === "function"
          ? getI18nMessage("plansDataMissing", "データの読み込みに必要な情報が不足しています")
          : "データの読み込みに必要な情報が不足しています";
        this.showError(chartContainer, missing);
        // エラー時もフラグは維持して、無限リトライを防ぐ
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
            const loadFailed = typeof getI18nMessage === "function"
              ? getI18nMessage("plansLoadFailed", "読み込みに失敗しました")
              : "読み込みに失敗しました";
            throw new Error(data.message || loadFailed);
          }
          const planData = data.data;

          // レガシースクリプトが読み込まれるまで待機してから
          // データ準備と属性設定を行う
          return this.waitForGanttScripts().then(() => {
            const ganttData = window.prepareGanttData(planData);
            window.setGanttDataAttributes(chartContainer, ganttData);

            // 二重初期化ガード解除 → 初期化
            if (chartContainer.dataset.ganttInitialized === "true") {
              delete chartContainer.dataset.ganttInitialized;
            }
            window.initCustomGanttChart();
            // 成功時はフラグは既に true のまま
          });
        })
        .catch((err) => {
          console.error("[plans-show] load error", err);
          const loadFailed =
            typeof getI18nMessage === "function"
              ? getI18nMessage("plansLoadFailed", "読み込みに失敗しました")
              : "読み込みに失敗しました";
          const ganttNotLoaded =
            typeof getI18nMessage === "function"
              ? getI18nMessage(
                  "plansGanttNotLoaded",
                  "ガントチャート機能が読み込まれていません（スクリプトの読み込みに失敗した可能性があります）"
                )
              : "ガントチャート機能が読み込まれていません（スクリプトの読み込みに失敗した可能性があります）";
          this.showError(chartContainer, `${loadFailed}: ${err.message}`);
          // レガシーJS読み込みタイムアウト時は、後続イベントでの再試行を許可するためフラグをリセットする
          if (
            err &&
            typeof err.message === "string" &&
            err.message.includes(ganttNotLoaded)
          ) {
            this._hasInitialized = false;
          }
        });
    } catch (e) {
      console.error("[plans-show] initializeGantt error", e);
      // エラー時もフラグは維持して、無限リトライを防ぐ
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
