/**
 * Loading System - ローディング表示の統一管理
 * 
 * プログレス表示、スピナー表示を統一的に管理
 */

class LoadingSystem {
  constructor() {
    this.activeLoadings = new Map();
    this.injectStyles();
  }

  /**
   * ローディング用スタイルを挿入
   */
  injectStyles() {
    if (document.getElementById('loading-system-styles')) return;

    const style = document.createElement('style');
    style.id = 'loading-system-styles';
    style.textContent = `
      @keyframes loadingSpinnerRotate {
        from { transform: rotate(0deg); }
        to { transform: rotate(360deg); }
      }

      @keyframes loadingFadeIn {
        from { opacity: 0; }
        to { opacity: 1; }
      }

      .loading-overlay {
        position: fixed;
        top: 0;
        left: 0;
        width: 100%;
        height: 100%;
        background-color: rgba(0, 0, 0, 0.5);
        z-index: 10003;
        display: flex;
        justify-content: center;
        align-items: center;
        cursor: not-allowed;
        animation: loadingFadeIn 0.2s ease-out;
      }

      .loading-content {
        background-color: white;
        padding: 30px 40px;
        border-radius: 12px;
        box-shadow: 0 10px 25px rgba(0, 0, 0, 0.2);
        text-align: center;
        min-width: 280px;
      }

      .loading-spinner {
        border: 4px solid #f3f4f6;
        border-top: 4px solid #3b82f6;
        border-radius: 50%;
        width: 48px;
        height: 48px;
        animation: loadingSpinnerRotate 1s linear infinite;
        margin: 0 auto 20px auto;
      }

      .loading-message {
        font-size: 16px;
        font-weight: 600;
        color: #374151;
        margin-bottom: 12px;
      }

      .loading-submessage {
        font-size: 13px;
        color: #6B7280;
        margin-bottom: 16px;
      }

      .loading-progress-bar {
        width: 100%;
        height: 6px;
        background-color: #E5E7EB;
        border-radius: 3px;
        overflow: hidden;
        margin-top: 16px;
      }

      .loading-progress-fill {
        height: 100%;
        background-color: #3B82F6;
        border-radius: 3px;
        transition: width 0.3s ease-out;
      }

      .loading-progress-percentage {
        font-size: 24px;
        font-weight: 700;
        color: #3B82F6;
        margin-bottom: 8px;
      }
    `;
    document.head.appendChild(style);
  }

  /**
   * ローディングIDを生成
   */
  generateId() {
    return `loading-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  }

  /**
   * ローディングを表示
   */
  show({ message = '処理中...', submessage = '', showProgress = false, progress = 0 } = {}) {
    const id = this.generateId();

    const overlay = document.createElement('div');
    overlay.className = 'loading-overlay';
    overlay.id = id;

    const content = document.createElement('div');
    content.className = 'loading-content';

    content.innerHTML = `
      <div class="loading-spinner"></div>
      <div class="loading-message">${message}</div>
      ${submessage ? `<div class="loading-submessage">${submessage}</div>` : ''}
      ${showProgress ? `
        <div class="loading-progress-percentage">${progress}%</div>
        <div class="loading-progress-bar">
          <div class="loading-progress-fill" style="width: ${progress}%"></div>
        </div>
      ` : ''}
    `;

    overlay.appendChild(content);
    document.body.appendChild(overlay);

    this.activeLoadings.set(id, { overlay, message, submessage, showProgress, progress });

    return id;
  }

  /**
   * ローディングメッセージを更新
   */
  updateMessage(id, message, submessage = '') {
    const loading = this.activeLoadings.get(id);
    if (!loading) return;

    const overlay = document.getElementById(id);
    if (!overlay) return;

    const messageEl = overlay.querySelector('.loading-message');
    const submessageEl = overlay.querySelector('.loading-submessage');

    if (messageEl) messageEl.textContent = message;
    if (submessage && submessageEl) {
      submessageEl.textContent = submessage;
    } else if (submessage && !submessageEl) {
      const submsgDiv = document.createElement('div');
      submsgDiv.className = 'loading-submessage';
      submsgDiv.textContent = submessage;
      messageEl.after(submsgDiv);
    }

    loading.message = message;
    loading.submessage = submessage;
  }

  /**
   * プログレスを更新
   */
  updateProgress(id, progress, message = '') {
    const loading = this.activeLoadings.get(id);
    if (!loading || !loading.showProgress) return;

    const overlay = document.getElementById(id);
    if (!overlay) return;

    const percentageEl = overlay.querySelector('.loading-progress-percentage');
    const fillEl = overlay.querySelector('.loading-progress-fill');

    if (percentageEl) percentageEl.textContent = `${progress}%`;
    if (fillEl) fillEl.style.width = `${progress}%`;

    if (message) {
      this.updateMessage(id, message);
    }

    loading.progress = progress;
  }

  /**
   * ローディングを非表示
   */
  hide(id) {
    const overlay = document.getElementById(id);
    if (overlay) {
      overlay.style.animation = 'loadingFadeIn 0.2s ease-in reverse';
      setTimeout(() => {
        overlay.remove();
        this.activeLoadings.delete(id);
      }, 200);
    }
  }

  /**
   * すべてのローディングを非表示
   */
  hideAll() {
    this.activeLoadings.forEach((_, id) => this.hide(id));
  }
}

// グローバルインスタンスを作成
window.loadingSystemInstance = new LoadingSystem();

/**
 * グローバルAPI
 */
window.Loading = {
  /**
   * ローディングを表示
   */
  show(message, options = {}) {
    return window.loadingSystemInstance.show({ message, ...options });
  },

  /**
   * プログレス付きローディングを表示
   */
  showProgress(message = '処理中...', progress = 0) {
    return window.loadingSystemInstance.show({ message, showProgress: true, progress });
  },

  /**
   * メッセージを更新
   */
  updateMessage(id, message, submessage) {
    window.loadingSystemInstance.updateMessage(id, message, submessage);
  },

  /**
   * プログレスを更新
   */
  updateProgress(id, progress, message) {
    window.loadingSystemInstance.updateProgress(id, progress, message);
  },

  /**
   * ローディングを非表示
   */
  hide(id) {
    window.loadingSystemInstance.hide(id);
  },

  /**
   * すべてのローディングを非表示
   */
  hideAll() {
    window.loadingSystemInstance.hideAll();
  }
};

console.log('✅ Loading System loaded');

