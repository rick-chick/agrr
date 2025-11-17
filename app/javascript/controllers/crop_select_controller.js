import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="crop-select"
export default class extends Controller {
  static targets = ["counter", "submit", "hint"];

  connect() {
    // 初期状態を更新
    this.updateState();
  }

  checkboxElements() {
    return this.element.querySelectorAll('input[type="checkbox"].crop-check');
  }

  selectedCount() {
    return Array.from(this.checkboxElements()).filter((el) => el.checked).length;
  }

  updateState() {
    const count = this.selectedCount();
    
    if (this.hasCounterTarget) {
      this.counterTarget.textContent = String(count);
    }
    
    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = count === 0;
    }
    
    if (this.hasHintTarget) {
      this.hintTarget.style.display = count === 0 ? "block" : "none";
    }
  }
}


