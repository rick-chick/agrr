/**
 * Dialog System - confirm/prompt/alert の代替
 * 
 * ネイティブのalert/confirm/promptを置き換える
 * モダンでカスタマイズ可能なダイアログを提供
 */

class DialogSystem {
  constructor() {
    this.activeDialogs = new Set();
    this.injectStyles();
  }

  /**
   * ダイアログ用スタイルを挿入
   */
  injectStyles() {
    if (document.getElementById('dialog-system-styles')) return;

    const style = document.createElement('style');
    style.id = 'dialog-system-styles';
    style.textContent = `
      @keyframes dialogBackdropFadeIn {
        from { opacity: 0; }
        to { opacity: 1; }
      }

      @keyframes dialogSlideUp {
        from {
          transform: translate(-50%, 100%);
          opacity: 0;
        }
        to {
          transform: translate(-50%, -50%);
          opacity: 1;
        }
      }

      @keyframes dialogSlideDown {
        from {
          transform: translate(-50%, -50%);
          opacity: 1;
        }
        to {
          transform: translate(-50%, 100%);
          opacity: 0;
        }
      }

      .dialog-backdrop {
        position: fixed;
        top: 0;
        left: 0;
        width: 100%;
        height: 100%;
        background-color: rgba(0, 0, 0, 0.5);
        z-index: 10001;
        display: flex;
        align-items: center;
        justify-content: center;
        animation: dialogBackdropFadeIn 0.2s ease-out;
      }

      .dialog-content {
        position: fixed;
        top: 50%;
        left: 50%;
        transform: translate(-50%, -50%);
        background-color: white;
        border-radius: 12px;
        box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04);
        max-width: 90%;
        width: 400px;
        z-index: 10002;
        animation: dialogSlideUp 0.3s cubic-bezier(0.34, 1.56, 0.64, 1);
      }

      .dialog-content.closing {
        animation: dialogSlideDown 0.2s ease-in;
      }

      .dialog-header {
        padding: 24px 24px 16px 24px;
        border-bottom: 1px solid #E5E7EB;
      }

      .dialog-title {
        margin: 0;
        font-size: 18px;
        font-weight: 600;
        color: #111827;
        display: flex;
        align-items: center;
        gap: 12px;
      }

      .dialog-body {
        padding: 20px 24px;
        color: #4B5563;
        font-size: 14px;
        line-height: 1.6;
      }

      .dialog-footer {
        padding: 16px 24px;
        border-top: 1px solid #E5E7EB;
        display: flex;
        gap: 12px;
        justify-content: flex-end;
      }

      .dialog-button {
        padding: 10px 20px;
        border-radius: 6px;
        font-size: 14px;
        font-weight: 600;
        cursor: pointer;
        transition: all 0.2s;
        border: none;
        outline: none;
      }

      .dialog-button-primary {
        background-color: #3B82F6;
        color: white;
      }

      .dialog-button-primary:hover {
        background-color: #2563EB;
      }

      .dialog-button-danger {
        background-color: #EF4444;
        color: white;
      }

      .dialog-button-danger:hover {
        background-color: #DC2626;
      }

      .dialog-button-secondary {
        background-color: #F3F4F6;
        color: #374151;
      }

      .dialog-button-secondary:hover {
        background-color: #E5E7EB;
      }

      .dialog-input {
        width: 100%;
        padding: 10px 12px;
        border: 1px solid #D1D5DB;
        border-radius: 6px;
        font-size: 14px;
        outline: none;
        transition: border-color 0.2s;
      }

      .dialog-input:focus {
        border-color: #3B82F6;
        box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
      }
    `;
    document.head.appendChild(style);
  }

  /**
   * ダイアログIDを生成
   */
  generateId() {
    return `dialog-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  }

  /**
   * ダイアログを表示
   */
  show({ title, message, icon, buttons, input, onClose }) {
    return new Promise((resolve) => {
      const id = this.generateId();
      
      // バックドロップ
      const backdrop = document.createElement('div');
      backdrop.className = 'dialog-backdrop';
      backdrop.id = `${id}-backdrop`;
      
      // ダイアログコンテンツ
      const dialog = document.createElement('div');
      dialog.className = 'dialog-content';
      dialog.id = id;

      // ヘッダー
      const header = document.createElement('div');
      header.className = 'dialog-header';
      header.innerHTML = `
        <h3 class="dialog-title">
          ${icon || ''}
          <span>${title}</span>
        </h3>
      `;

      // ボディ
      const body = document.createElement('div');
      body.className = 'dialog-body';
      body.innerHTML = message;

      // 入力フィールド（promptの場合）
      if (input) {
        const inputElement = document.createElement('input');
        inputElement.type = input.type || 'text';
        inputElement.className = 'dialog-input';
        inputElement.placeholder = input.placeholder || '';
        inputElement.value = input.defaultValue || '';
        inputElement.id = `${id}-input`;
        body.appendChild(document.createElement('br'));
        body.appendChild(document.createElement('br'));
        body.appendChild(inputElement);
        
        // Enterキーで送信
        setTimeout(() => {
          inputElement.focus();
          inputElement.select();
        }, 100);
      }

      // フッター（ボタン）
      const footer = document.createElement('div');
      footer.className = 'dialog-footer';
      
      buttons.forEach(button => {
        const btn = document.createElement('button');
        btn.className = `dialog-button dialog-button-${button.style || 'secondary'}`;
        btn.textContent = button.text;
        btn.onclick = () => {
          const inputValue = input ? document.getElementById(`${id}-input`).value : null;
          this.close(id, () => {
            resolve({ action: button.action, value: inputValue });
            if (button.callback) button.callback(inputValue);
          });
        };
        footer.appendChild(btn);
      });

      // 組み立て
      dialog.appendChild(header);
      dialog.appendChild(body);
      dialog.appendChild(footer);
      
      backdrop.appendChild(dialog);
      document.body.appendChild(backdrop);

      this.activeDialogs.add(id);

      // バックドロップクリックで閉じる（オプション）
      backdrop.addEventListener('click', (e) => {
        if (e.target === backdrop) {
          const cancelButton = buttons.find(b => b.action === 'cancel');
          if (cancelButton) {
            this.close(id, () => {
              resolve({ action: 'cancel', value: null });
              if (onClose) onClose();
            });
          }
        }
      });

      // Escapeキーで閉じる
      const escapeHandler = (e) => {
        if (e.key === 'Escape') {
          const cancelButton = buttons.find(b => b.action === 'cancel');
          if (cancelButton) {
            this.close(id, () => {
              resolve({ action: 'cancel', value: null });
              if (onClose) onClose();
            });
            document.removeEventListener('keydown', escapeHandler);
          }
        }
      };
      document.addEventListener('keydown', escapeHandler);

      // Enterキーで確定（入力ダイアログの場合）
      if (input) {
        const enterHandler = (e) => {
          if (e.key === 'Enter') {
            const confirmButton = buttons.find(b => b.action === 'confirm' || b.action === 'ok');
            if (confirmButton) {
              const inputValue = document.getElementById(`${id}-input`).value;
              this.close(id, () => {
                resolve({ action: confirmButton.action, value: inputValue });
                if (confirmButton.callback) confirmButton.callback(inputValue);
              });
              document.removeEventListener('keydown', enterHandler);
            }
          }
        };
        document.addEventListener('keydown', enterHandler);
      }
    });
  }

  /**
   * ダイアログを閉じる
   */
  close(id, callback) {
    const dialog = document.getElementById(id);
    const backdrop = document.getElementById(`${id}-backdrop`);
    
    if (dialog) {
      dialog.classList.add('closing');
      setTimeout(() => {
        backdrop?.remove();
        this.activeDialogs.delete(id);
        if (callback) callback();
      }, 200);
    }
  }

  /**
   * アラート（alert代替）
   */
  alert(message, title = '通知') {
    return this.show({
      title,
      message,
      icon: `<svg style="width: 24px; height: 24px; color: #3B82F6;" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
      </svg>`,
      buttons: [
        { text: 'OK', action: 'ok', style: 'primary' }
      ]
    });
  }

  /**
   * 確認ダイアログ（confirm代替）
   */
  confirm(message, { title = '確認', confirmText = '確認', cancelText = 'キャンセル', danger = false } = {}) {
    return this.show({
      title,
      message,
      icon: `<svg style="width: 24px; height: 24px; color: ${danger ? '#EF4444' : '#F59E0B'};" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"></path>
      </svg>`,
      buttons: [
        { text: cancelText, action: 'cancel', style: 'secondary' },
        { text: confirmText, action: 'confirm', style: danger ? 'danger' : 'primary' }
      ]
    });
  }

  /**
   * 入力ダイアログ（prompt代替）
   */
  prompt(message, { title = '入力', defaultValue = '', placeholder = '', confirmText = 'OK', cancelText = 'キャンセル', type = 'text' } = {}) {
    return this.show({
      title,
      message,
      icon: `<svg style="width: 24px; height: 24px; color: #3B82F6;" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z"></path>
      </svg>`,
      input: {
        type,
        defaultValue,
        placeholder
      },
      buttons: [
        { text: cancelText, action: 'cancel', style: 'secondary' },
        { text: confirmText, action: 'confirm', style: 'primary' }
      ]
    });
  }
}

// グローバルインスタンスを作成
window.dialogSystemInstance = new DialogSystem();

/**
 * グローバルAPI - ネイティブダイアログの代替
 */
window.Dialog = {
  /**
   * アラートを表示（alert代替）
   */
  alert(message, title) {
    return window.dialogSystemInstance.alert(message, title);
  },

  /**
   * 確認ダイアログを表示（confirm代替）
   */
  confirm(message, options) {
    return window.dialogSystemInstance.confirm(message, options);
  },

  /**
   * 入力ダイアログを表示（prompt代替）
   */
  prompt(message, options) {
    return window.dialogSystemInstance.prompt(message, options);
  }
};

console.log('✅ Dialog System loaded');

