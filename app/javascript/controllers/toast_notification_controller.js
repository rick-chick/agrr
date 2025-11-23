import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = {
    type: { type: String, default: "info" },
    message: String,
    autoShow: { type: Boolean, default: false }
  };

  connect() {
    if (this.autoShowValue && this.messageValue) {
      // 少し遅延させて表示（ページ読み込み後に表示）
      setTimeout(() => {
        this.showToast(this.typeValue, this.messageValue);
      }, 1000);
    }
  }

  showToast(type, message) {
    if (!message) return;

    // トースト要素を作成
    const toast = document.createElement("div");
    toast.className = `toast toast-${type || "info"}`;
    toast.textContent = message;
    toast.style.cssText = `
      position: fixed;
      top: 20px;
      right: 20px;
      padding: 12px 24px;
      background-color: ${type === "warning" ? "#ff9800" : type === "error" ? "#f44336" : "#2196f3"};
      color: white;
      border-radius: 4px;
      box-shadow: 0 2px 8px rgba(0,0,0,0.2);
      z-index: 10000;
      animation: slideIn 0.3s ease-out;
      max-width: 400px;
      word-wrap: break-word;
    `;

    // アニメーション用のCSSを追加（まだ追加されていない場合）
    if (!document.getElementById("toast-animations")) {
      const style = document.createElement("style");
      style.id = "toast-animations";
      style.textContent = `
        @keyframes slideIn {
          from {
            transform: translateX(100%);
            opacity: 0;
          }
          to {
            transform: translateX(0);
            opacity: 1;
          }
        }
        @keyframes slideOut {
          from {
            transform: translateX(0);
            opacity: 1;
          }
          to {
            transform: translateX(100%);
            opacity: 0;
          }
        }
      `;
      document.head.appendChild(style);
    }

    document.body.appendChild(toast);

    // 5秒後に自動で削除
    setTimeout(() => {
      toast.style.animation = "slideOut 0.3s ease-out";
      setTimeout(() => {
        if (toast.parentNode) {
          toast.parentNode.removeChild(toast);
        }
      }, 300);
    }, 5000);
  }
}
